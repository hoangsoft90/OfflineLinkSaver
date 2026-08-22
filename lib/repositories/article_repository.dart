import '../models/article.dart';
import '../models/article_status.dart';
import '../core/database/database_helper.dart';
import '../core/storage/storage_helper.dart';
import '../core/network/url_helper.dart';
import 'package:uuid/uuid.dart';

class ArticleRepository {
  static const _uuid = Uuid();

  /// Insert new article with queued status
  Future<Article?> insertArticle({
    required String originalUrl,
    required String title,
    String? author,
    String? excerpt,
    String? coverImagePath,
    String? categoryId,
  }) async {
    final db = await DatabaseHelper.database;
    
    final canonicalUrl = UrlHelper.canonicalizeUrl(originalUrl);
    final domain = UrlHelper.extractDomain(originalUrl);
    
    // Check for duplicate
    final existing = await db.query(
      'articles',
      where: 'canonical_url = ?',
      whereArgs: [canonicalUrl],
    );
    
    if (existing.isNotEmpty) {
      return Article.fromMap(existing.first);
    }

    final id = _uuid.v4();
    final now = DateTime.now();

    final article = Article(
      id: id,
      originalUrl: originalUrl,
      canonicalUrl: canonicalUrl,
      title: title,
      domain: domain,
      author: author,
      excerpt: excerpt,
      coverImagePath: coverImagePath,
      categoryId: categoryId,
      status: ArticleStatus.queued,
      createdAt: now,
      updatedAt: now,
    );

    await db.insert('articles', article.toMap());
    return article;
  }

  /// Get all articles with filters
  Future<List<Article>> getArticles({
    String? status,
    bool? isRead,
    bool? isFavorite,
    String? categoryId,
    String? searchQuery,
    String? orderBy,
  }) async {
    final db = await DatabaseHelper.database;
    
    final where = <String>[];
    final args = <dynamic>[];

    if (status != null) {
      where.add('status = ?');
      args.add(status);
    }
    if (isRead != null) {
      where.add('is_read = ?');
      args.add(isRead ? 1 : 0);
    }
    if (isFavorite == true) {
      where.add('is_favorite = ?');
      args.add(1);
    }
    if (categoryId != null) {
      where.add('category_id = ?');
      args.add(categoryId);
    }
    if (searchQuery != null && searchQuery.isNotEmpty) {
      where.add('(title LIKE ? OR domain LIKE ?)');
      args.add('%$searchQuery%');
      args.add('%$searchQuery%');
    }

    final results = await db.query(
      'articles',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: orderBy ?? 'created_at DESC',
    );

    return results.map((map) => Article.fromMap(map)).toList();
  }

  /// Get single article by ID with self-heal
  Future<Article?> getArticle(String id) async {
    final db = await DatabaseHelper.database;
    
    final results = await db.query(
      'articles',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (results.isEmpty) return null;

    final article = Article.fromMap(results.first);

    if (article.status == ArticleStatus.ready) {
      final isValid = await StorageHelper.verifyArticleContent(id);
      if (!isValid) {
        await updateArticleStatus(id, ArticleStatus.failed, 
          errorMessage: 'Content file missing or corrupted');
        article.status = ArticleStatus.failed;
        article.errorMessage = 'Content file missing or corrupted';
      }
    }

    return article;
  }

  /// Update article status
  Future<void> updateArticleStatus(
    String id,
    ArticleStatus status, {
    String? errorMessage,
  }) async {
    final db = await DatabaseHelper.database;
    
    final updates = <String, dynamic>{
      'status': status.value,
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (errorMessage != null) {
      updates['error_message'] = errorMessage;
    }

    await db.update('articles', updates, where: 'id = ?', whereArgs: [id]);
  }

  /// Update article fields
  Future<void> updateArticle(String id, Map<String, dynamic> updates) async {
    final db = await DatabaseHelper.database;
    updates['updated_at'] = DateTime.now().toIso8601String();
    await db.update('articles', updates, where: 'id = ?', whereArgs: [id]);
  }

  /// Update reading progress
  Future<void> updateReadingProgress(String id, double progress) async {
    final db = await DatabaseHelper.database;
    await db.update(
      'articles',
      {'reading_progress': progress, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Mark article as read
  Future<void> markAsRead(String id) async {
    final db = await DatabaseHelper.database;
    await db.update(
      'articles',
      {'is_read': 1, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Toggle favorite status
  Future<void> toggleFavorite(String id) async {
    final db = await DatabaseHelper.database;
    await db.rawUpdate(
      '''UPDATE articles 
         SET is_favorite = CASE WHEN is_favorite = 1 THEN 0 ELSE 1 END,
             updated_at = ?
         WHERE id = ?''',
      [DateTime.now().toIso8601String(), id],
    );
  }

  /// Set category for an article
  Future<void> setCategory(String articleId, String? categoryId) async {
    final db = await DatabaseHelper.database;
    await db.update(
      'articles',
      {'category_id': categoryId, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [articleId],
    );
  }

  /// Delete article and its files
  Future<void> deleteArticle(String id) async {
    final db = await DatabaseHelper.database;
    await StorageHelper.deleteArticleDirectory(id);
    await db.delete('articles', where: 'id = ?', whereArgs: [id]);
  }

  /// Get unread articles
  Future<List<Article>> getUnreadArticles() async {
    return getArticles(isRead: false);
  }

  /// Get downloaded articles
  Future<List<Article>> getDownloadedArticles() async {
    return getArticles(status: ArticleStatus.ready.value);
  }

  /// Get favorites
  Future<List<Article>> getFavorites() async {
    return getArticles(isFavorite: true);
  }

  /// Get articles by category
  Future<List<Article>> getArticlesByCategory(String categoryId, {String? searchQuery}) async {
    return getArticles(categoryId: categoryId, searchQuery: searchQuery);
  }

  /// Search articles
  Future<List<Article>> searchArticles(String query) async {
    return getArticles(searchQuery: query);
  }

  /// Get article count by status
  Future<int> getArticleCountByStatus(ArticleStatus status) async {
    final db = await DatabaseHelper.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM articles WHERE status = ?',
      [status.value],
    );
    return result.first['count'] as int;
  }

  /// Get total article count
  Future<int> getTotalArticleCount() async {
    final db = await DatabaseHelper.database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM articles');
    return result.first['count'] as int;
  }

  /// Get storage usage
  Future<int> getStorageUsage() async {
    return await StorageHelper.getStorageUsage();
  }
}
