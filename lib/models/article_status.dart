enum ArticleStatus {
  queued,       // waiting in queue
  downloading,  // fetching HTTP
  processing,   // parsing/sanitizing/normalizing/downloading images
  ready,        // complete, read offline 100%
  failed,       // error that CAN be retried (network, timeout, temporary parse)
  online_only,  // determined that offline article CANNOT be created — keeps URL/metadata
}

extension ArticleStatusExtension on ArticleStatus {
  String get value => name;
  
  String get displayName {
    switch (this) {
      case ArticleStatus.queued:
        return 'Queued';
      case ArticleStatus.downloading:
        return 'Downloading';
      case ArticleStatus.processing:
        return 'Processing';
      case ArticleStatus.ready:
        return 'Ready';
      case ArticleStatus.failed:
        return 'Failed';
      case ArticleStatus.online_only:
        return 'Online Only';
    }
  }

  String get statusMessage {
    switch (this) {
      case ArticleStatus.queued:
        return '⏳ Waiting to download…';
      case ArticleStatus.downloading:
        return '⏳ Downloading…';
      case ArticleStatus.processing:
        return '⏳ Processing…';
      case ArticleStatus.ready:
        return '✓ Saved · Offline copy ready';
      case ArticleStatus.failed:
        return '⚠ Download failed';
      case ArticleStatus.online_only:
        return '⚠ Offline copy unavailable';
    }
  }

  bool get canBeRetried {
    return this == ArticleStatus.failed || this == ArticleStatus.online_only;
  }

  bool get isDownloadInProgress {
    return this == ArticleStatus.downloading || 
           this == ArticleStatus.processing ||
           this == ArticleStatus.queued;
  }

  static ArticleStatus fromString(String value) {
    return ArticleStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => ArticleStatus.failed,
    );
  }
}
