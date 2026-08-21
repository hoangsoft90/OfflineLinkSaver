import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import '../../repositories/article_repository.dart';
import '../../core/network/url_helper.dart';
import '../../core/network/network_client.dart';
import '../../services/downloader/download_queue_manager.dart';

/// Handler for Android share sheet integration.
///
/// Edge cases handled:
/// - Empty / whitespace-only / plain-text (non-URL) input
/// - Double-fire: `getInitialMedia` + `getMediaStream` can both fire for the
///   same intent — guarded by [_lastProcessedUrl].
/// - HEAD request timeout: resolved URL falls back to original.
/// - Concurrent share events: processed sequentially via queue.
class ShareHandler {
  final ArticleRepository _repository;
  final DownloadQueueManager _downloadQueue;

  StreamSubscription<List<SharedMediaFile>>? _subscription;
  final _shareController = StreamController<ShareEvent>.broadcast();

  /// Guards against double-processing the same URL from two streams.
  String? _lastProcessedUrl;

  /// Queue for serializing concurrent share events.
  final Completer<void> _queueHead = Completer<void>()..complete();
  Completer<void> _queueTail = Completer<void>()..complete();

  ShareHandler({
    required ArticleRepository repository,
    required DownloadQueueManager downloadQueue,
  })  : _repository = repository,
        _downloadQueue = downloadQueue;

  /// Stream of share events for UI feedback
  Stream<ShareEvent> get shareEvents => _shareController.stream;

  /// Initialize share intent listener
  void initialize() {
    // Listen for shared media (fires while app is running)
    ReceiveSharingIntent.instance.getMediaStream().listen(
      _handleSharedMedia,
      onError: (error) {
        debugPrint('[ShareHandler] MediaStream error: $error');
      },
    );

    // Check for initial shared media (app opened via share intent)
    ReceiveSharingIntent.instance.getInitialMedia().then((media) {
      if (media.isNotEmpty) {
        _handleSharedMedia(media);
      }
    });
  }

  /// Handle shared media files
  Future<void> _handleSharedMedia(List<SharedMediaFile> media) async {
    for (final file in media) {
      final text = file.path;
      if (text.isNotEmpty) {
        await _enqueueSharedText(text);
      }
    }
  }

  /// Serialize share events to prevent race conditions.
  Future<void> _enqueueSharedText(String text) async {
    final prevTail = _queueTail;
    _queueTail = Completer<void>();

    await prevTail.future;
    try {
      await _handleSharedText(text);
    } finally {
      prevTail.complete();
    }
  }

  /// Handle shared text (URL).
  ///
  /// Edge-case guards:
  /// 1. Null / empty / whitespace-only → reject immediately.
  /// 2. Not a valid HTTP(S) URL → reject with clear message.
  /// 3. Dangerous scheme (javascript:, file:, etc.) → reject.
  /// 4. Double-fire protection → skip if same URL was just processed.
  /// 5. HEAD timeout → falls back to original URL.
  Future<void> _handleSharedText(String text) async {
    // ── Guard 1: null / empty / whitespace ──
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      _emit(ShareEvent(
        success: false,
        message: 'Empty share content',
        url: text,
      ));
      return;
    }

    // ── Guard 2: must be http(s) URL ──
    if (!UrlHelper.isValidUrl(trimmed)) {
      _emit(ShareEvent(
        success: false,
        message: 'Not a valid URL: only http/https links are supported',
        url: trimmed,
      ));
      return;
    }

    // ── Guard 3: dangerous scheme ──
    if (UrlHelper.isDangerousScheme(trimmed)) {
      _emit(ShareEvent(
        success: false,
        message: 'Unsupported link type',
        url: trimmed,
      ));
      return;
    }

    // ── Guard 4: double-fire protection ──
    final canonicalCheck = UrlHelper.canonicalizeUrl(trimmed);
    if (_lastProcessedUrl == canonicalCheck) {
      // Same URL arriving from both getInitialMedia and getMediaStream
      return;
    }
    _lastProcessedUrl = canonicalCheck;

    // Clear the guard after 3 seconds to allow re-sharing same URL later.
    Future.delayed(const Duration(seconds: 3), () {
      if (_lastProcessedUrl == canonicalCheck) {
        _lastProcessedUrl = null;
      }
    });

    // ── Resolve redirects (with timeout) ──
    String resolvedUrl = trimmed;
    try {
      final response = await NetworkClient.fetchHead(trimmed)
          .timeout(const Duration(seconds: 8));
      final finalUrl = response.request?.url.toString();
      if (finalUrl != null && finalUrl.isNotEmpty) {
        resolvedUrl = finalUrl;
      }
    } catch (e) {
      // HEAD failed or timed out — use original URL
      debugPrint('[ShareHandler] HEAD resolve failed: $e');
    }

    // Canonicalize for duplicate check
    final canonicalUrl = UrlHelper.canonicalizeUrl(resolvedUrl);

    // ── Duplicate check (exact match) ──
    try {
      final existingArticles = await _repository.getArticles();
      final isDuplicate =
          existingArticles.any((a) => a.canonicalUrl == canonicalUrl);
      if (isDuplicate) {
        final existing =
            existingArticles.firstWhere((a) => a.canonicalUrl == canonicalUrl);
        _emit(ShareEvent(
          success: false,
          message: 'Already saved on ${_formatDate(existing.createdAt)}',
          url: resolvedUrl,
          existingArticleId: existing.id,
        ));
        return;
      }
    } catch (e) {
      debugPrint('[ShareHandler] Duplicate check failed: $e');
      // Continue anyway — better to save twice than lose a share
    }

    // ── Save article ──
    try {
      final article = await _repository.insertArticle(
        originalUrl: resolvedUrl,
        title: _extractTitleFromUrl(resolvedUrl),
      );

      if (article != null) {
        _downloadQueue.enqueue(article.id);

        _emit(ShareEvent(
          success: true,
          message: '✓ Saved',
          url: resolvedUrl,
          articleId: article.id,
        ));
      } else {
        // insertArticle returns null only when duplicate — but we checked above
        _emit(ShareEvent(
          success: false,
          message: 'Failed to save',
          url: resolvedUrl,
        ));
      }
    } catch (e) {
      _emit(ShareEvent(
        success: false,
        message: 'Error saving: $e',
        url: resolvedUrl,
      ));
    }
  }

  /// Safe emit that catches controller-closed errors.
  void _emit(ShareEvent event) {
    if (!_shareController.isClosed) {
      _shareController.add(event);
    }
  }

  /// Format date for display
  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }

  /// Extract title from URL (simple fallback)
  String _extractTitleFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final host = uri.host.replaceFirst('www.', '');
      final path = uri.path;
      if (path.isEmpty || path == '/') {
        return host;
      }
      final segments = path.split('/').where((s) => s.isNotEmpty).toList();
      if (segments.isEmpty) return host;
      final lastSegment = segments.last;
      final cleaned = lastSegment
          .replaceAll(RegExp(r'[_-]'), ' ')
          .replaceAll(RegExp(r'\.(html?|php|aspx?)$'), '');
      if (cleaned.length < 3) return host;
      return '$host / $cleaned';
    } catch (e) {
      return url;
    }
  }

  /// Dispose resources
  void dispose() {
    _subscription?.cancel();
    _shareController.close();
  }
}

/// Share event for UI feedback
class ShareEvent {
  final bool success;
  final String message;
  final String url;
  final String? articleId;
  final String? existingArticleId;

  ShareEvent({
    required this.success,
    required this.message,
    required this.url,
    this.articleId,
    this.existingArticleId,
  });
}
