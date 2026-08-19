# Module: Extractor

## Overview

The Extractor module is responsible for extracting article content from URLs. It uses a 2-tier approach: fast HTTP extraction first, then WebView fallback for JavaScript-heavy sites.

## Architecture

```
┌─────────────────────────────────────────────────────┐
│              DownloadQueueManager                    │
│                  (calls extract)                     │
└──────────────────────┬──────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────┐
│             HttpExtractor (Layer 1)                  │
│  - Fetch HTML via NetworkClient                     │
│  - Parse with `html` package                        │
│  - Heuristic content detection                      │
│  - Returns ExtractionResult                         │
└──────────────────────┬──────────────────────────────┘
                       │ (if < 200 words or error)
                       ▼
┌─────────────────────────────────────────────────────┐
│        WebViewFallbackExtractor (Layer 2)            │
│  - Load URL in WebViewController                    │
│  - Wait for page load + 2s delay                    │
│  - Extract via JavaScript                           │
│  - Concurrency: 1 instance max                      │
│  - Timeout: 10 seconds                              │
└──────────────────────┬──────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────┐
│                Sanitizer                             │
│  - Remove <script>, <iframe>, <object>, <embed>     │
│  - Remove javascript: URLs                          │
│  - Remove on*= event attributes                     │
│  - Validate image URLs (http/https only)            │
└─────────────────────────────────────────────────────┘
```

---

## Layer 1: HTTP Extractor

### File: `lib/services/extractor/http_extractor.dart`

### How It Works

1. **Fetch HTML** via `NetworkClient.fetchWithRedirects(url)`
2. **Parse HTML** using `html` package
3. **Find article content** using heuristics:
   - Try `<article>` tag first
   - Try `.post-content`, `.article-content`, `.entry-content`
   - Try `<main>` tag
   - Fallback to `<body>`
4. **Extract blocks** from child elements:
   - `<h1>`–`<h6>` → heading block
   - `<p>` → paragraph block
   - `<img>` → image block
   - `<blockquote>` → quote block
   - `<ul>`, `<ol>` → list block
   - `<pre>`, `<code>` → code block
5. **Extract metadata**:
   - Title: `og:title` → `<title>` → `<h1>`
   - Author: `meta[name="author"]` → `.author` → `.byline`
   - Excerpt: `og:description` → `meta[name="description"]` → first `<p>`
   - Cover: `og:image` → first `<img>` in article

### Thresholds

| Parameter | Value | Action on Fail |
|---|---|---|
| Min word count | 200 | Trigger WebView fallback |
| HTTP timeout | 15s | Return ExtractionResult(success: false) |
| Max response size | 2MB | Throw exception |
| Max redirect hops | 5 | Throw exception |

### ExtractionResult

```dart
class ExtractionResult {
  final bool success;
  final ArticleContent? content;
  final String? title;
  final String? author;
  final String? excerpt;
  final String? coverImage;
  final String? error;
  final bool needsWebView;  // true if should try WebView fallback
}
```

---

## Layer 2: WebView Fallback Extractor

### File: `lib/services/extractor/webview_fallback_extractor.dart`

### When It's Used

- HTTP extractor returns `< 200 words`
- HTTP extractor fails with error
- Site requires JavaScript rendering (SPAs)

### How It Works

1. **Create WebViewController**
2. **Set JavaScript mode** to unrestricted
3. **Load URL** and wait for page finish
4. **Wait 2 seconds** for dynamic content
5. **Run JavaScript** to extract content:
   - Find article element (same heuristics as Layer 1)
   - Extract blocks via DOM queries
   - Extract metadata from meta tags
6. **Parse JSON result** back to Dart objects
7. **Return ExtractionResult**

### Constraints

| Parameter | Value |
|---|---|
| Concurrency | 1 WebView at a time |
| Render timeout | 10 seconds |
| Min word count | 200 (same as Layer 1) |

### Limitations (Accepted)

WebView fallback is **best-effort**, not guaranteed:
- Bot protection (Cloudflare, etc.)
- Cookie consent overlays
- Infinite scroll
- Paywalls
- Auth-gated content

These cases result in `online_only` status, which is expected behavior.

---

## Sanitizer

### File: `lib/services/extractor/sanitizer.dart`

### What It Removes

| Pattern | Action |
|---|---|
| `<script>...</script>` | Remove entire tag |
| `<iframe>...</iframe>` | Remove entire tag |
| `<object>...</object>` | Remove entire tag |
| `<embed>...</embed>` | Remove entire tag |
| `<form>...</form>` | Remove entire tag |
| `javascript:` URLs | Remove |
| `on*=` attributes | Remove |
| Non-http/https image URLs | Skip image |
| Remaining HTML tags | Strip (text only) |

### Usage

```dart
final sanitizer = Sanitizer();
final sanitizedBlocks = sanitizer.sanitize(extractedBlocks);
```

---

## Content Block Model

### Block Types

```dart
enum BlockType {
  heading,    // <h1>–<h6>
  paragraph,  // <p>
  image,      // <img>
  quote,      // <blockquote>
  list,       // <ul>, <ol>
  code,       // <pre>, <code>
  link,       // <a>
}
```

### Block Structure

```dart
class ContentBlock {
  final BlockType type;
  final String? text;           // heading, paragraph, quote, code
  final String? imageUrl;       // image
  final String? altText;        // image
  final String? caption;        // image
  final List<String>? items;    // list
  final int? level;             // heading (1-6)
  final String? language;       // code
  final String? url;            // link
}
```

### ArticleContent

```dart
class ArticleContent {
  final List<ContentBlock> blocks;
  
  String toPlainText() { ... }  // For word count
  int get wordCount { ... }     // Computed
}
```

---

## Error Handling

### HTTP Extractor Errors

```dart
try {
  result = await _httpExtractor.extract(article.originalUrl);
} catch (e) {
  result = ExtractionResult(
    success: false,
    error: e.toString(),
  );
}
```

### WebView Errors

```dart
try {
  await _webViewSemaphore.acquire();
  result = await _webViewExtractor.extract(article.originalUrl);
  _webViewSemaphore.release();
} catch (e) {
  result = ExtractionResult(
    success: false,
    error: e.toString(),
  );
}
```

### Final Decision

```dart
if (result == null || !result.success || result.content == null) {
  // Determine if permanent failure
  final status = result?.error?.contains('bot protection') == true
      ? ArticleStatus.online_only
      : ArticleStatus.failed;
  
  await _repository.updateArticleStatus(
    articleId,
    status,
    errorMessage: 'Extraction failed: ${result?.error ?? "Unknown error"}',
  );
}
```

---

## Testing

### Test Cases

1. **Successful HTTP extraction** — Popular blog post
2. **HTTP extraction failure** — SPA site (triggers WebView)
3. **Both layers fail** — Bot-protected site → `online_only`
4. **Minimal content** — Short article → `online_only`
5. **Redirect chain** — URL with multiple redirects
6. **Timeout** — Slow site → `failed` (retryable)

### Test Sites (from spec)

Test 15-20 diverse sites:
- News articles (NYT, BBC)
- Blog posts (Medium, Dev.to)
- Tech articles (HackerNews, StackOverflow)
- SPA sites (requires JavaScript)
- Bot-protected sites (Cloudflare)
- Paywalled sites
- Sites with redirect chains

---

## Key Decisions

1. **2-tier extraction** — Fast HTTP first, WebView only when needed
2. **200-word threshold** — Below this, content is likely incomplete
3. **15-second timeout** — Balance between waiting and failing fast
4. **15 images max** — Prevent storage abuse while keeping most content
5. **UUID filenames** — Prevent path traversal attacks
6. **Best-effort WebView** — Don't promise 100% site support
