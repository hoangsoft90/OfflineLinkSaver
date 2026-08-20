import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:uuid/uuid.dart';
import '../../models/article_status.dart';
import '../../models/content_block.dart';
import '../../repositories/article_repository.dart';
import '../../core/storage/storage_helper.dart';
import '../extractor/http_extractor.dart';
import '../extractor/webview_fallback_extractor.dart';
import '../extractor/sanitizer.dart';

/// Download queue manager with separate concurrency for HTTP and WebView
class DownloadQueueManager {
  static const int _httpConcurrency = 2;
  static const int _webViewConcurrency = 1;
  static const int _maxImagesPerArticle = 15;
  static const int _maxImageSizeBytes = 5 * 1024 * 1024; // 5MB
  static const int _maxTotalArticleSizeBytes = 50 * 1024 * 1024; // 50MB

  final ArticleRepository _repository;
  final HttpExtractor _httpExtractor;
  final WebViewFallbackExtractor _webViewExtractor;
  final Sanitizer _sanitizer;

  final _httpSemaphore = _Semaphore(_httpConcurrency);
  final _webViewSemaphore = _Semaphore(_webViewConcurrency);
  
  final _queue = <String>[];
  final _processing = <String>{};
  
  bool _isProcessing = false;
  StreamController<DownloadProgress>? _progressController;

  DownloadQueueManager({
    required ArticleRepository repository,
  })  : _repository = repository,
        _httpExtractor = HttpExtractor(),
        _webViewExtractor = WebViewFallbackExtractor(),
        _sanitizer = Sanitizer();

  /// Stream of download progress updates
  Stream<DownloadProgress> get progressStream {
    _progressController ??= StreamController<DownloadProgress>.broadcast();
    return _progressController!.stream;
  }

  /// Add article to download queue
  void enqueue(String articleId) {
    if (!_queue.contains(articleId) && !_processing.contains(articleId)) {
      _queue.add(articleId);
      _processQueue();
    }
  }

  /// Add multiple articles to download queue
  void enqueueAll(List<String> articleIds) {
    for (final id in articleIds) {
      if (!_queue.contains(id) && !_processing.contains(id)) {
        _queue.add(id);
      }
    }
    _processQueue();
  }

  /// Get queue length
  int get queueLength => _queue.length + _processing.length;

  /// Get processing count
  int get processingCount => _processing.length;

  /// Process queue if slots available
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

  /// Try to start downloads based on available slots
  void _tryStartDownloads() {
    // Check HTTP slots
    while (_httpSemaphore.available > 0 && _queue.isNotEmpty) {
      final articleId = _queue.removeAt(0);
      _processing.add(articleId);
      _httpSemaphore.acquire();
      _processArticle(articleId);
    }
  }

  /// Process a single article
  Future<void> _processArticle(String articleId) async {
    try {
      // Get article from repository
      final article = await _repository.getArticle(articleId);
      if (article == null) {
        _finishArticle(articleId);
        return;
      }

      // Update status to downloading
      await _repository.updateArticleStatus(articleId, ArticleStatus.downloading);
      _emitProgress(articleId, 'Downloading...');

      // Try HTTP extractor first
      ExtractionResult? result;
      try {
        result = await _httpExtractor.extract(article.originalUrl);
      } catch (e) {
        result = ExtractionResult(
          success: false,
          error: e.toString(),
        );
      }

      // If HTTP fails, try WebView fallback
      if (!result.success && result.needsWebView) {
        _emitProgress(articleId, 'Trying alternative method...');
        final httpError = result.error; // Preserve HTTP error for fallback
        
        try {
          await _webViewSemaphore.acquire();
          final webViewResult = await _webViewExtractor.extract(article.originalUrl);
          _webViewSemaphore.release();
          
          if (webViewResult != null) {
            result = webViewResult;
          } else {
            // WebView returned null - keep original HTTP error
            result = ExtractionResult(
              success: false,
              error: httpError ?? 'WebView extraction failed',
            );
          }
        } catch (e) {
          result = ExtractionResult(
            success: false,
            error: httpError ?? e.toString(),
          );
        }
      }

      if (result == null || !result.success || result.content == null) {
        // Extraction failed - mark as failed or online_only
        final status = result?.error?.contains('bot protection') == true
            ? ArticleStatus.online_only
            : ArticleStatus.failed;
        
        await _repository.updateArticleStatus(
          articleId,
          status,
          errorMessage: 'Extraction failed: ${result?.error ?? "Unknown error"}',
        );
        _finishArticle(articleId);
        return;
      }

      // Sanitize content
      final sanitizedBlocks = _sanitizer.sanitize(result.content!.blocks);
      final sanitizedContent = ArticleContent(blocks: sanitizedBlocks);

      // Update status to processing
      await _repository.updateArticleStatus(articleId, ArticleStatus.processing);
      _emitProgress(articleId, 'Saving content...');

      // Create temp directory
      final tempDir = await StorageHelper.createTempArticleDirectory(articleId);

      // Save content.json
      final contentJson = sanitizedContent.toJson();
      final contentFile = File('$tempDir/content.json');
      await contentFile.writeAsString(
        const JsonEncoder.withIndent('  ').convert(contentJson),
      );

      // Download images
      await _downloadImages(articleId, sanitizedBlocks, tempDir);

      // Verify content
      final isValid = await StorageHelper.verifyArticleContent(articleId);
      if (!isValid) {
        await _repository.updateArticleStatus(
          articleId,
          ArticleStatus.failed,
          errorMessage: 'Content verification failed',
        );
        _finishArticle(articleId);
        return;
      }

      // Finalize: rename temp to final directory
      final finalized = await StorageHelper.finalizeArticleDirectory(articleId);
      if (!finalized) {
        await _repository.updateArticleStatus(
          articleId,
          ArticleStatus.failed,
          errorMessage: 'Failed to save content',
        );
        _finishArticle(articleId);
        return;
      }

      // Update article with content path and metadata
      final contentPath = await StorageHelper.getContentPath(articleId);
      await _repository.updateArticle(articleId, {
        'content_path': contentPath,
        'title': result.title ?? article.title,
        'author': result.author,
        'excerpt': result.excerpt,
        'cover_image_path': result.coverImage,
        'status': ArticleStatus.ready.value,
      });

      _emitProgress(articleId, 'Ready');
    } catch (e) {
      await _repository.updateArticleStatus(
        articleId,
        ArticleStatus.failed,
        errorMessage: 'Download failed: $e',
      );
    } finally {
      _finishArticle(articleId);
    }
  }

  /// Download images from content blocks
  Future<void> _downloadImages(
    String articleId,
    List<ContentBlock> blocks,
    String tempDir,
  ) async {
    final imagesDir = Directory('$tempDir/images');
    if (!await imagesDir.exists()) {
      await imagesDir.create(recursive: true);
    }

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

        final httpClientRequest = response;
        final httpClientResponse = await httpClientRequest.close();

        if (httpClientResponse.statusCode == 200) {
          final bytes = await httpClientResponse.toList();
          final bytesList = bytes.expand((i) => i).toList();
          
          if (bytesList.length <= _maxImageSizeBytes) {
            // Generate UUID filename
            final imageUuid = const Uuid().v4();
            final filename = '$imageUuid.jpg';
            final file = File('${imagesDir.path}/$filename');
            
            await file.writeAsBytes(bytesList);
            totalSize += bytesList.length;
            imageCount++;
          }
        }
      } catch (e) {
        // Skip failed images - don't fail entire article
        continue;
      }
    }
  }

  /// Mark article as finished processing
  void _finishArticle(String articleId) {
    _processing.remove(articleId);
    _httpSemaphore.release();
    _tryStartDownloads();
  }

  /// Emit progress update
  void _emitProgress(String articleId, String message) {
    _progressController?.add(DownloadProgress(
      articleId: articleId,
      message: message,
      queueLength: _queue.length,
      processingCount: _processing.length,
    ));
  }

  /// Dispose resources
  void dispose() {
    _progressController?.close();
  }
}

/// Simple semaphore for concurrency control
class _Semaphore {
  int _current;

  _Semaphore(int maxCount) : _current = maxCount;

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

/// Download progress information
class DownloadProgress {
  final String articleId;
  final String message;
  final int queueLength;
  final int processingCount;

  DownloadProgress({
    required this.articleId,
    required this.message,
    required this.queueLength,
    required this.processingCount,
  });
}
