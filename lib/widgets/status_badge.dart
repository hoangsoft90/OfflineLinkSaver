import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/article_status.dart';

/// Badge widget to display article download status
class StatusBadge extends StatelessWidget {
  final ArticleStatus status;
  final VoidCallback? onRetry;

  const StatusBadge({
    super.key,
    required this.status,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _getBackgroundColor(),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getIcon(),
            size: 14,
            color: _getIconColor(),
          ),
          const SizedBox(width: 4),
          Text(
            _getText(l10n),
            style: TextStyle(
              color: _getIconColor(),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (status.canBeRetried && onRetry != null) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onRetry,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  l10n.statusRetry,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _getBackgroundColor() {
    switch (status) {
      case ArticleStatus.ready:
        return Colors.green.shade50;
      case ArticleStatus.downloading:
      case ArticleStatus.processing:
      case ArticleStatus.queued:
        return Colors.blue.shade50;
      case ArticleStatus.failed:
        return Colors.red.shade50;
      case ArticleStatus.online_only:
        return Colors.orange.shade50;
    }
  }

  Color _getIconColor() {
    switch (status) {
      case ArticleStatus.ready:
        return Colors.green.shade700;
      case ArticleStatus.downloading:
      case ArticleStatus.processing:
      case ArticleStatus.queued:
        return Colors.blue.shade700;
      case ArticleStatus.failed:
        return Colors.red.shade700;
      case ArticleStatus.online_only:
        return Colors.orange.shade700;
    }
  }

  IconData _getIcon() {
    switch (status) {
      case ArticleStatus.ready:
        return Icons.check_circle;
      case ArticleStatus.downloading:
        return Icons.downloading;
      case ArticleStatus.processing:
        return Icons.sync;
      case ArticleStatus.queued:
        return Icons.schedule;
      case ArticleStatus.failed:
        return Icons.error;
      case ArticleStatus.online_only:
        return Icons.language;
    }
  }

  String _getText(AppLocalizations l10n) {
    switch (status) {
      case ArticleStatus.ready:
        return l10n.statusReady;
      case ArticleStatus.downloading:
        return l10n.statusDownloading;
      case ArticleStatus.processing:
        return l10n.statusProcessing;
      case ArticleStatus.queued:
        return l10n.statusQueued;
      case ArticleStatus.failed:
        return l10n.statusFailed;
      case ArticleStatus.online_only:
        return l10n.statusOnlineOnly;
    }
  }
}
