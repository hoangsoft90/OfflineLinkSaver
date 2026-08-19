import 'package:flutter_test/flutter_test.dart';
import 'package:offline_link_saver/models/article.dart';
import 'package:offline_link_saver/models/article_status.dart';

void main() {
  group('Article', () {
    test('creates article with required fields', () {
      final now = DateTime.now();
      final article = Article(
        id: 'test-id',
        originalUrl: 'https://example.com/article',
        canonicalUrl: 'https://example.com/article',
        title: 'Test Article',
        domain: 'example.com',
        status: ArticleStatus.queued,
        createdAt: now,
        updatedAt: now,
      );

      expect(article.id, 'test-id');
      expect(article.originalUrl, 'https://example.com/article');
      expect(article.canonicalUrl, 'https://example.com/article');
      expect(article.title, 'Test Article');
      expect(article.domain, 'example.com');
      expect(article.status, ArticleStatus.queued);
      expect(article.isRead, false);
      expect(article.isFavorite, false);
      expect(article.readingProgress, 0.0);
    });

    test('creates article with optional fields', () {
      final now = DateTime.now();
      final article = Article(
        id: 'test-id',
        originalUrl: 'https://example.com/article',
        canonicalUrl: 'https://example.com/article',
        title: 'Test Article',
        domain: 'example.com',
        author: 'John Doe',
        excerpt: 'This is a test article',
        coverImagePath: '/path/to/image.jpg',
        contentPath: '/path/to/content.json',
        status: ArticleStatus.ready,
        extractorVersion: 2,
        isRead: true,
        isFavorite: true,
        readingProgress: 0.75,
        errorMessage: 'Test error',
        createdAt: now,
        updatedAt: now,
      );

      expect(article.author, 'John Doe');
      expect(article.excerpt, 'This is a test article');
      expect(article.coverImagePath, '/path/to/image.jpg');
      expect(article.contentPath, '/path/to/content.json');
      expect(article.status, ArticleStatus.ready);
      expect(article.extractorVersion, 2);
      expect(article.isRead, true);
      expect(article.isFavorite, true);
      expect(article.readingProgress, 0.75);
      expect(article.errorMessage, 'Test error');
    });

    test('toMap creates correct map', () {
      final now = DateTime.now();
      final article = Article(
        id: 'test-id',
        originalUrl: 'https://example.com/article',
        canonicalUrl: 'https://example.com/article',
        title: 'Test Article',
        domain: 'example.com',
        status: ArticleStatus.queued,
        createdAt: now,
        updatedAt: now,
      );

      final map = article.toMap();
      expect(map['id'], 'test-id');
      expect(map['original_url'], 'https://example.com/article');
      expect(map['canonical_url'], 'https://example.com/article');
      expect(map['title'], 'Test Article');
      expect(map['domain'], 'example.com');
      expect(map['status'], 'queued');
      expect(map['is_read'], 0);
      expect(map['is_favorite'], 0);
      expect(map['reading_progress'], 0.0);
    });

    test('fromMap creates article correctly', () {
      final now = DateTime.now();
      final map = {
        'id': 'test-id',
        'original_url': 'https://example.com/article',
        'canonical_url': 'https://example.com/article',
        'title': 'Test Article',
        'domain': 'example.com',
        'author': 'John Doe',
        'excerpt': 'This is a test article',
        'cover_image_path': '/path/to/image.jpg',
        'content_path': '/path/to/content.json',
        'status': 'ready',
        'extractor_version': 2,
        'is_read': 1,
        'is_favorite': 1,
        'reading_progress': 0.75,
        'error_message': 'Test error',
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      };

      final article = Article.fromMap(map);
      expect(article.id, 'test-id');
      expect(article.originalUrl, 'https://example.com/article');
      expect(article.author, 'John Doe');
      expect(article.status, ArticleStatus.ready);
      expect(article.isRead, true);
      expect(article.isFavorite, true);
      expect(article.readingProgress, 0.75);
    });

    test('copyWith creates copy with changes', () {
      final now = DateTime.now();
      final article = Article(
        id: 'test-id',
        originalUrl: 'https://example.com/article',
        canonicalUrl: 'https://example.com/article',
        title: 'Test Article',
        domain: 'example.com',
        status: ArticleStatus.queued,
        createdAt: now,
        updatedAt: now,
      );

      final updatedArticle = article.copyWith(
        title: 'Updated Title',
        status: ArticleStatus.ready,
      );

      expect(updatedArticle.id, article.id);
      expect(updatedArticle.title, 'Updated Title');
      expect(updatedArticle.status, ArticleStatus.ready);
      expect(updatedArticle.originalUrl, article.originalUrl);
    });

    test('copyWith preserves original values when not specified', () {
      final now = DateTime.now();
      final article = Article(
        id: 'test-id',
        originalUrl: 'https://example.com/article',
        canonicalUrl: 'https://example.com/article',
        title: 'Test Article',
        domain: 'example.com',
        author: 'John Doe',
        status: ArticleStatus.queued,
        createdAt: now,
        updatedAt: now,
      );

      final copiedArticle = article.copyWith();
      expect(copiedArticle.title, article.title);
      expect(copiedArticle.author, article.author);
      expect(copiedArticle.status, article.status);
    });
  });
}
