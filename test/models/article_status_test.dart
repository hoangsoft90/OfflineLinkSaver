import 'package:flutter_test/flutter_test.dart';
import 'package:offline_link_saver/models/article_status.dart';

void main() {
  group('ArticleStatus', () {
    test('has correct string values', () {
      expect(ArticleStatus.queued.value, 'queued');
      expect(ArticleStatus.downloading.value, 'downloading');
      expect(ArticleStatus.processing.value, 'processing');
      expect(ArticleStatus.ready.value, 'ready');
      expect(ArticleStatus.failed.value, 'failed');
      expect(ArticleStatus.online_only.value, 'online_only');
    });

    test('fromString returns correct status', () {
      expect(ArticleStatusExtension.fromString('queued'), ArticleStatus.queued);
      expect(ArticleStatusExtension.fromString('downloading'), ArticleStatus.downloading);
      expect(ArticleStatusExtension.fromString('processing'), ArticleStatus.processing);
      expect(ArticleStatusExtension.fromString('ready'), ArticleStatus.ready);
      expect(ArticleStatusExtension.fromString('failed'), ArticleStatus.failed);
      expect(ArticleStatusExtension.fromString('online_only'), ArticleStatus.online_only);
    });

    test('fromString returns failed for unknown status', () {
      expect(ArticleStatusExtension.fromString('unknown'), ArticleStatus.failed);
    });

    test('displayName is correct', () {
      expect(ArticleStatus.queued.displayName, 'Queued');
      expect(ArticleStatus.downloading.displayName, 'Downloading');
      expect(ArticleStatus.processing.displayName, 'Processing');
      expect(ArticleStatus.ready.displayName, 'Ready');
      expect(ArticleStatus.failed.displayName, 'Failed');
      expect(ArticleStatus.online_only.displayName, 'Online Only');
    });

    test('canBeRetried is true for failed and online_only', () {
      expect(ArticleStatus.failed.canBeRetried, true);
      expect(ArticleStatus.online_only.canBeRetried, true);
      expect(ArticleStatus.ready.canBeRetried, false);
      expect(ArticleStatus.queued.canBeRetried, false);
      expect(ArticleStatus.downloading.canBeRetried, false);
      expect(ArticleStatus.processing.canBeRetried, false);
    });

    test('isDownloadInProgress is true for queued, downloading, processing', () {
      expect(ArticleStatus.queued.isDownloadInProgress, true);
      expect(ArticleStatus.downloading.isDownloadInProgress, true);
      expect(ArticleStatus.processing.isDownloadInProgress, true);
      expect(ArticleStatus.ready.isDownloadInProgress, false);
      expect(ArticleStatus.failed.isDownloadInProgress, false);
      expect(ArticleStatus.online_only.isDownloadInProgress, false);
    });
  });
}
