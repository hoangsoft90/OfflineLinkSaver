# State Machine & Data Models

## Article Status State Machine

### States

```dart
enum ArticleStatus {
  queued,       // Waiting in download queue
  downloading,  // HTTP fetch in progress
  processing,   // Parsing, sanitizing, downloading images
  ready,        // Complete — 100% offline reading available
  failed,       // Error that CAN be retried (network, timeout, temporary parse)
  online_only,  // Permanent failure — URL/metadata kept, no offline content
}
```

### State Transitions

```
                    ┌─────────────────────────────────────┐
                    │                                     │
                    ▼                                     │
    ┌─────────┐  ┌──────────────┐  ┌─────────────┐  ┌────┴────┐
    │ queued  │→│ downloading  │→│ processing   │→│  ready   │
    └─────────┘  └──────────────┘  └─────────────┘  └─────────┘
         │              │                 │
         │              │                 │
         ▼              ▼                 ▼
    ┌─────────┐  ┌──────────────┐  ┌─────────────┐
    │ failed  │←─│ failed       │←─│ failed      │
    └─────────┘  └──────────────┘  └─────────────┘
         │
         │  (permanent failure - bot protection, paywall, etc.)
         ▼
    ┌──────────────┐
    │ online_only  │
    └──────────────┘
```

### Transition Rules

| From | To | Trigger |
|---|---|---|
| `queued` | `downloading` | Queue slot available, download starts |
| `downloading` | `processing` | HTTP/WebView extraction succeeds |
| `processing` | `ready` | Content verified, atomic write complete |
| `downloading` | `failed` | Network error, timeout, extraction fail |
| `processing` | `failed` | Content verification failed |
| `downloading` | `online_only` | Bot protection detected (permanent) |
| `processing` | `online_only` | Permanent extraction failure |
| `failed` | `queued` | User taps Retry |
| `online_only` | `queued` | User taps Retry |
| `*` (stuck) | `queued` | Startup sanitization (app restart) |

### Status Semantics

**`failed` vs `online_only`:**
- `failed` = temporary error (network, timeout, parse issue) — likely to succeed on retry
- `online_only` = determined that offline content CANNOT be created — needs user action or website change

**Startup Sanitization:**
```sql
UPDATE articles SET status = 'queued'
WHERE status IN ('downloading', 'processing');
```
This runs EVERY time the app opens. It handles the case where OS killed the process mid-download.

---

## Data Models

### Article

The core entity — represents a saved link.

```dart
class Article {
  final String id;                    // UUID v4
  final String originalUrl;           // Never overwritten (audit trail)
  final String canonicalUrl;          // After redirect + tracking strip
  String title;                       // Extracted or fallback from URL
  String domain;                      // Extracted from URL
  String? author;                     // Extracted from meta tags
  String? excerpt;                    // Extracted from meta description
  String? coverImagePath;             // Local path, UUID filename
  String? contentPath;                // Path to content.json
  ArticleStatus status;               // Current state
  int extractorVersion;               // For re-extraction marking
  bool isRead;                        // User has opened this article
  bool isFavorite;                    // User marked as favorite (P1)
  double readingProgress;             // 0.0–1.0 (scroll position)
  String? errorMessage;               // Human-readable, nullable
  final DateTime createdAt;           // When link was saved
  DateTime updatedAt;                 // Updated on every status change
}
```

### ContentBlock

Individual content element within an article.

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

class ContentBlock {
  final BlockType type;
  final String? text;           // For heading, paragraph, quote, code
  final String? imageUrl;       // For image
  final String? altText;        // For image
  final String? caption;        // For image
  final List<String>? items;    // For list
  final int? level;             // For heading (1-6)
  final String? language;       // For code block
  final String? url;            // For link
}
```

### ArticleContent

Collection of blocks representing a full article.

```dart
class ArticleContent {
  final List<ContentBlock> blocks;
  
  String toPlainText();  // For word count
  int get wordCount;     // Computed from blocks
}
```

### Content JSON Format

```json
{
  "blocks": [
    {
      "type": "heading",
      "text": "Article Title",
      "level": 1
    },
    {
      "type": "paragraph",
      "text": "Lorem ipsum dolor sit amet..."
    },
    {
      "type": "image",
      "imageUrl": "images/550e8400-e29b-41d4-a716-446655440000.jpg",
      "altText": "Description of image"
    },
    {
      "type": "list",
      "items": ["First item", "Second item", "Third item"]
    }
  ]
}
```

---

## SQLite Schema

### articles Table

```sql
CREATE TABLE articles (
    id TEXT PRIMARY KEY,
    original_url TEXT NOT NULL,
    canonical_url TEXT NOT NULL UNIQUE,
    title TEXT NOT NULL,
    domain TEXT NOT NULL,
    author TEXT,
    excerpt TEXT,
    cover_image_path TEXT,
    content_path TEXT,
    status TEXT NOT NULL DEFAULT 'queued',
    extractor_version INTEGER DEFAULT 1,
    is_read INTEGER DEFAULT 0,
    is_favorite INTEGER DEFAULT 0,
    reading_progress REAL DEFAULT 0.0,
    error_message TEXT,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
);
```

### Indexes

```sql
CREATE INDEX idx_articles_status ON articles(status);
CREATE INDEX idx_articles_is_read ON articles(is_read);
CREATE INDEX idx_articles_canonical_url ON articles(canonical_url);
CREATE INDEX idx_articles_domain ON articles(domain);
```

### Migration Strategy

- Use `PRAGMA user_version` for version tracking
- Currently at version 1 (base schema)
- Each migration preserves existing data
- Migrations are in `DatabaseHelper._onUpgrade()`

---

## Download Queue State

### Queue Manager State

```dart
class DownloadQueueManager {
  final _queue = <String>[];        // Waiting article IDs
  final _processing = <String>{};   // Currently downloading
  
  // Concurrency control
  final _httpSemaphore = _Semaphore(2);    // 2 parallel HTTP
  final _webViewSemaphore = _Semaphore(1); // 1 WebView at a time
}
```

### Queue Processing Flow

```
enqueue(articleId)
    ↓
add to _queue
    ↓
_processQueue() — Timer.periodic(100ms)
    ↓
_tryStartDownloads()
    ├─ HTTP slot available? → Start HTTP download
    └─ No slots? → Wait
    ↓
_processArticle(articleId)
    ├─ Update status → downloading
    ├─ Try HTTP Extractor
    │   ├─ Success → Continue
    │   └─ Fail → Try WebView (acquire semaphore)
    ├─ Sanitize content
    ├─ Update status → processing
    ├─ Write to temp dir
    ├─ Download images
    ├─ Verify content
    ├─ Atomic rename
    ├─ Update status → ready
    └─ Release semaphore
```

### Limits

| Parameter | Value | Rationale |
|---|---|---|
| HTTP concurrency | 2 | Balance speed vs resource usage |
| WebView concurrency | 1 | WebView is resource-heavy |
| HTTP timeout | 15s | Prevent hanging connections |
| Max redirect hops | 5 | Prevent redirect loops |
| Max response size | 2MB | Safety guard against oversized HTML |
| Max images/article | 15 | Prevent storage abuse |
| Max image size | 5MB | Skip oversized images |
| Max total article size | 50MB | Keep text, drop excess images |
| Min word count | 200 | Below this triggers WebView fallback |

---

## URL Canonicalization

### Tracking Parameters Stripped

```dart
static const List<String> _trackingParams = [
  'utm_source', 'utm_medium', 'utm_campaign', 'utm_term', 'utm_content',
  'fbclid', 'gclid', 'msclkid', 'ref',
  'mc_cid', 'mc_eid',
];
```

### Example

```
Original:  https://example.com/article?utm_source=twitter&fbclid=abc123&id=456
Canonical: https://example.com/article?id=456
```

### Duplicate Detection
- Articles are checked by `canonical_url` (UNIQUE constraint)
- If duplicate found, returns existing article
- UI shows "Already saved on [date]"

---

## File System Layout

### Active Download
```
/articles/{id}.tmp/
├── content.json          # Article content (block-based JSON)
└── images/
    ├── {uuid1}.jpg       # UUID-based filenames
    ├── {uuid2}.jpg
    └── ...
```

### Verified Article
```
/articles/{id}/           # Only exists after verification
├── content.json
└── images/
    ├── {uuid1}.jpg
    └── ...
```

### Atomic Write Steps
1. Create `{id}.tmp/` directory
2. Write `content.json`
3. Download images (UUID filenames)
4. Verify `content.json` exists + valid JSON
5. Rename `{id}.tmp/` → `{id}/`
6. If step 4-5 fails, `.tmp/` cleaned up on next startup

### Self-Heal on Read
```dart
// ArticleRepository.getArticle()
if (article.status == ArticleStatus.ready) {
  final isValid = await StorageHelper.verifyArticleContent(id);
  if (!isValid) {
    // Content missing/corrupted → mark failed
    await updateArticleStatus(id, ArticleStatus.failed, 
      errorMessage: 'Content file missing or corrupted');
  }
}
```
