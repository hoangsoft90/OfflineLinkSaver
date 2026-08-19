# Module: Downloader

## Overview

The Downloader module manages the download queue, orchestrates the extraction pipeline, and handles content storage. It coordinates between the Extractor services and Storage layer.

## Architecture

```
┌─────────────────────────────────────────────────────┐
│            DownloadQueueManager                      │
│  - Queue management                                  │
│  - Concurrency control (HTTP=2, WebView=1)           │
│  - State machine transitions                         │
│  - Progress reporting                                │
└──────────────────────┬──────────────────────────────┘
                       │
         ┌─────────────┼─────────────┐
         ▼             ▼             ▼
    ┌─────────┐  ┌──────────┐  ┌──────────┐
    │ Http    │  │ WebView  │  │ Sanitizer│
    │Extract. │  │ Fallback │  │          │
    └─────────┘  └──────────┘  └──────────┘
         │             │             │
         └─────────────┼─────────────┘
                       ▼
              ┌────────────────┐
              │ StorageHelper  │
              │ (atomic write) │
              └────────────────┘
```

---

## DownloadQueueManager

### File: `lib/services/downloader/download_queue_manager.dart`

### Responsibilities

1. Accept article IDs for download
2. Manage download concurrency
3. Orchestrate extraction pipeline
4. Handle content storage
5. Report progress to UI

### Concurrency Model

```dart
static const int _httpConcurrency = 2;     // Parallel HTTP downloads
static const int _webViewConcurrency = 1;  // Single WebView instance
```

### Queue State

```dart
final _queue = <String>[];        // Waiting article IDs
final _processing = <String>{};   // Currently downloading

// Concurrency control
final _httpSemaphore = _Semaphore(2);
final _webViewSemaphore = _Semaphore(1);
```

---

## Download Flow

### Step 1: Enqueue

```dart
void enqueue(String articleId) {
  if (!_queue.contains(articleId) && !_processing.contains(articleId)) {
    _queue.add(articleId);
    _processQueue();
  }
}
```

### Step 2: Process Queue

```dart
void _processQueue() {
  if (_isProcessing) return;
  _isProcessing = true;

  Timer.periodic(const Duration(milliseconds: 100), (timer) {
    if (_queue.isEmpty && _processing.isEmpty) {
      timer.cancel();
      _isProcessing = false;
      return;
    }
    _tryStartDownloads();
  });
}
```

### Step 3: Start Downloads

```dart
void _tryStartDownloads() {
  while (_httpSemaphore.available > 0 && _queue.isNotEmpty) {
    final articleId = _queue.removeAt(0);
    _processing.add(articleId);
    _httpSemaphore.acquire();
    _processArticle(articleId);
  }
}
```

### Step 4: Process Article

```dart
Future<void> _processArticle(String articleId) async {
  try {
    // 1. Get article from repository
    final article = await _repository.getArticle(articleId);
    
    // 2. Update status → downloading
    await _repository.updateArticleStatus(articleId, ArticleStatus.downloading);
    
    // 3. Try HTTP extractor (Layer 1)
    ExtractionResult? result = await _httpExtractor.extract(article.originalUrl);
    
    // 4. If HTTP fails, try WebView (Layer 2)
    if (result != null && !result.success && result.needsWebView) {
      await _webViewSemaphore.acquire();
      result = await _webViewExtractor.extract(article.originalUrl);
      _webViewSemaphore.release();
    }
    
    // 5. Handle failure
    if (result == null || !result.success || result.content == null) {
      final status = result?.error?.contains('bot protection') == true
          ? ArticleStatus.online_only
          : ArticleStatus.failed;
      
      await _repository.updateArticleStatus(articleId, status,
        errorMessage: 'Extraction failed: ${result?.error ?? "Unknown error"}');
      return;
    }
    
    // 6. Sanitize content
    final sanitizedBlocks = _sanitizer.sanitize(result.content!.blocks);
    final sanitizedContent = ArticleContent(blocks: sanitizedBlocks);
    
    // 7. Update status → processing
    await _repository.updateArticleStatus(articleId, ArticleStatus.processing);
    
    // 8. Create temp directory
    final tempDir = await StorageHelper.createTempArticleDirectory(articleId);
    
    // 9. Save content.json
    final contentFile = File('$tempDir/content.json');
    await contentFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(sanitizedContent.toJson()),
    );
    
    // 10. Download images
    await _downloadImages(articleId, sanitizedBlocks, tempDir);
    
    // 11. Verify content
    final isValid = await StorageHelper.verifyArticleContent(articleId);
    if (!isValid) {
      await _repository.updateArticleStatus(articleId, ArticleStatus.failed,
        errorMessage: 'Content verification failed');
      return;
    }
    
    // 12. Finalize (atomic rename)
    final finalized = await StorageHelper.finalizeArticleDirectory(articleId);
    if (!finalized) {
      await _repository.updateArticleStatus(articleId, ArticleStatus.failed,
        errorMessage: 'Failed to save content');
      return;
    }
    
    // 13. Update article with content path
    final contentPath = await StorageHelper.getContentPath(articleId);
    await _repository.updateArticle(articleId, {
      'content_path': contentPath,
      'title': result.title ?? article.title,
      'author': result.author,
      'excerpt': result.excerpt,
      'cover_image_path': result.coverImage,
      'status': ArticleStatus.ready.value,
    });
    
  } catch (e) {
    await _repository.updateArticleStatus(articleId, ArticleStatus.failed,
      errorMessage: 'Download failed: $e');
  } finally {
    _finishArticle(articleId);
  }
}
```

---

## Image Download

### Constraints

| Parameter | Value | Rationale |
|---|---|---|
| Max images/article | 15 | Prevent storage abuse |
| Max size/image | 5MB | Skip oversized images |
| Max total size | 50MB | Keep text, drop excess images |
| Image timeout | 10s | Don't hang on slow images |

### Implementation

```dart
Future<void> _downloadImages(
  String articleId,
  List<ContentBlock> blocks,
  String tempDir,
) async {
  final imagesDir = Directory('$tempDir/images');
  await imagesDir.create(recursive: true);

  int imageCount = 0;
  int totalSize = 0;

  for (final block in blocks) {
    if (block.type != BlockType.image || block.imageUrl == null) continue;
    if (imageCount >= _maxImagesPerArticle) break;
    if (totalSize >= _maxTotalArticleSizeBytes) break;

    try {
      final imageUrl = block.imageUrl!;
      
      // Only download http/https images
      if (!imageUrl.startsWith('http://') && !imageUrl.startsWith('https://')) {
        continue;
      }

      // Download image
      final response = await HttpClient().getUrl(Uri.parse(imageUrl))
        .timeout(const Duration(seconds: 10));

      final httpClientResponse = await response.close();

      if (httpClientResponse.statusCode == 200) {
        final bytes = await httpClientResponse.toList();
        final bytesList = bytes.expand((i) => i).toList();
        
        if (bytesList.length <= _maxImageSizeBytes) {
          // Generate UUID filename (prevents path traversal)
          final imageUuid = const Uuid().v4();
          final filename = '$imageUuid.jpg';
          final file = File('${imagesDir.path}/$filename');
          
          await file.writeAsBytes(bytesList);
          totalSize += bytesList.length;
          imageCount++;
        }
      }
    } catch (e) {
      // Skip failed images — don't fail entire article
      continue;
    }
  }
}
```

### Key Decision: Image Failure Handling

If 3/15 images fail to download:
- Article still becomes `ready`
- Reader shows placeholder for missing images
- Article is NOT marked as `failed`

---

## Progress Reporting

### DownloadProgress

```dart
class DownloadProgress {
  final String articleId;
  final String message;
  final int queueLength;
  final int processingCount;
}
```

### Stream

```dart
Stream<DownloadProgress> get progressStream {
  _progressController ??= StreamController<DownloadProgress>.broadcast();
  return _progressController!.stream;
}
```

### Usage in UI

```dart
downloadQueue.progressStream.listen((progress) {
  // Update UI with progress
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(progress.message)),
  );
});
```

---

## Semaphore Implementation

```dart
class _Semaphore {
  final int _maxCount;
  int _current;

  _Semaphore(int maxCount) : _maxCount = maxCount, _current = maxCount;

  int get available => _current;

  Future<void> acquire() async {
    while (_current <= 0) {
      await Future.delayed(const Duration(milliseconds: 50));
    }
    _current--;
  }

  void release() {
    _current++;
  }
}
```

### Why Custom Semaphore?

- Flutter doesn't have built-in semaphore
- `async` package has `Pool` but adds dependency
- Simple implementation is sufficient for this use case
- 50ms polling is acceptable for download queue

---

## Error Handling

### Extraction Failure

```dart
if (result == null || !result.success || result.content == null) {
  // Determine if permanent failure
  final status = result?.error?.contains('bot protection') == true
      ? ArticleStatus.online_only
      : ArticleStatus.failed;
  
  await _repository.updateArticleStatus(articleId, status,
    errorMessage: 'Extraction failed: ${result?.error ?? "Unknown error"}');
}
```

### Image Download Failure

```dart
try {
  // Download image
} catch (e) {
  // Skip failed images — don't fail entire article
  continue;
}
```

### Content Verification Failure

```dart
final isValid = await StorageHelper.verifyArticleContent(articleId);
if (!isValid) {
  await _repository.updateArticleStatus(articleId, ArticleStatus.failed,
    errorMessage: 'Content verification failed');
  return;
}
```

### Atomic Write Failure

```dart
final finalized = await StorageHelper.finalizeArticleDirectory(articleId);
if (!finalized) {
  await _repository.updateArticleStatus(articleId, ArticleStatus.failed,
    errorMessage: 'Failed to save content');
  return;
}
```

---

## Cleanup

### Finish Article

```dart
void _finishArticle(String articleId) {
  _processing.remove(articleId);
  _httpSemaphore.release();
  _tryStartDownloads();  // Process next in queue
}
```

### Temp Directory Cleanup

If download fails, `.tmp/` directory remains until:
1. Next download attempt for same article (overwrites)
2. App restart (startup sanitization resets status)

---

## Testing

### Test Cases

1. **Successful download** — HTTP extraction → save → ready
2. **HTTP fails, WebView succeeds** — SPA site → ready
3. **Both layers fail** — Bot-protected → online_only
4. **Partial image failure** — 3/15 images fail → ready with placeholders
5. **Storage full** — Handle gracefully, no crash
6. **Concurrent downloads** — 5 articles queued → 2 download at a time
7. **Queue priority** — First-in-first-out processing
8. **Retry failed** — Tap retry → re-enqueue → download

### Performance

- HTTP concurrency: 2 parallel downloads
- WebView concurrency: 1 at a time
- Queue polling: 100ms interval
- Image download timeout: 10s per image
