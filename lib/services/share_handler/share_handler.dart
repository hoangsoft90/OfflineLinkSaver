import 'dart:async';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import '../../repositories/article_repository.dart';
import '../../core/network/url_helper.dart';
import '../../core/network/network_client.dart';
import '../../services/downloader/download_queue_manager.dart';

/// Handler for Android share sheet integration
class ShareHandler {
  final ArticleRepository _repository;
  final DownloadQueueManager _downloadQueue;
  
  StreamSubscription<List<SharedMediaFile>>? _subscription;
  final _shareController = StreamController<ShareEvent>.broadcast();

  ShareHandler({
    required ArticleRepository repository,
    required DownloadQueueManager downloadQueue,
  })  : _repository = repository,
        _downloadQueue = downloadQueue;

  /// Stream of share events for UI feedback
  Stream<ShareEvent> get shareEvents => _shareController.stream;

  /// Initialize share intent listener
  void initialize() {
    // Listen for shared media
    ReceiveSharingIntent.instance.getMediaStream().listen(
      _handleSharedMedia,
      onError: (error) {
        // Log error silently in production
      },
    );

    // Check for initial shared media (app opened via share)
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
        await _handleSharedText(text);
      }
    }
  }

  /// Handle shared text (URL)
  Future<void> _handleSharedText(String text) async {
    try {
      // Validate URL
      if (!UrlHelper.isValidUrl(text)) {
        _shareController.add(ShareEvent(
          success: false,
          message: 'Invalid URL',
          url: text,
        ));
        return;
      }

      if (UrlHelper.isDangerousScheme(text)) {
        _shareController.add(ShareEvent(
          success: false,
          message: 'Unsupported URL type',
          url: text,
        ));
        return;
      }

      // Resolve redirects (max 5 hops)
      String resolvedUrl;
      try {
        final response = await NetworkClient.fetchHead(text);
        resolvedUrl = response.request?.url.toString() ?? text;
      } catch (e) {
        resolvedUrl = text;
      }

      // Canonicalize URL
      final canonicalUrl = UrlHelper.canonicalizeUrl(resolvedUrl);

      // BUG 6: Use exact match instead of LIKE query for duplicate detection
      final existingArticles = await _repository.getArticles();
      final isDuplicate = existingArticles.any((a) => a.canonicalUrl == canonicalUrl);
      if (isDuplicate) {
        final existing = existingArticles.firstWhere((a) => a.canonicalUrl == canonicalUrl);
        _shareController.add(ShareEvent(
          success: false,
          message: 'Already saved on ${_formatDate(existing.createdAt)}',
          url: resolvedUrl,
          existingArticleId: existing.id,
        ));
        return;
      }

      // Insert article with queued status
      final article = await _repository.insertArticle(
        originalUrl: resolvedUrl,
        title: _extractTitleFromUrl(resolvedUrl),
      );

      if (article != null) {
        // Enqueue for download
        _downloadQueue.enqueue(article.id);

        _shareController.add(ShareEvent(
          success: true,
          message: '✓ Saved',
          url: resolvedUrl,
          articleId: article.id,
        ));
      } else {
        _shareController.add(ShareEvent(
          success: false,
          message: 'Failed to save',
          url: resolvedUrl,
        ));
      }
    } catch (e) {
      _shareController.add(ShareEvent(
        success: false,
        message: 'Error: $e',
        url: text,
      ));
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
      final path = uri.path;
      if (path.isEmpty || path == '/') {
        return uri.host;
      }
      // Use last path segment as title
      final segments = path.split('/');
      final lastSegment = segments.lastWhere((s) => s.isNotEmpty, orElse: () => '');
      return lastSegment.replaceAll('-', ' ').replaceAll('_', ' ');
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
