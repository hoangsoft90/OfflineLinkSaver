import '../models/article.dart';
import '../models/article_status.dart';
import '../core/database/database_helper.dart';
import '../core/storage/storage_helper.dart';
import '../core/network/url_helper.dart';
import 'package:uuid/uuid.dart';

class ArticleRepository {
  static const _uuid = Uuid();

  /// Insert new article with queued status
  /// Returns the article if successful, null if duplicate
  Future<Article?> insertArticle({
    required String originalUrl,
    required String title,
    String? author,
    String? excerpt,
    String? coverImagePath,
  }) async {
    final db = await DatabaseHelper.database;
    
    // Canonicalize URL for duplicate check
    final canonicalUrl = UrlHelper.canonicalizeUrl(originalUrl);
    final domain = UrlHelper.extractDomain(originalUrl);
    
    // Check for duplicate
    final existing = await db.query(
      'articles',
      where: 'canonical_url = ?',
      whereArgs: [canonicalUrl],
    );
    
    if (existing.isNotEmpty) {
      // Return existing article for duplicate handling
      return Article.fromMap(existing.first);
    }

    // Generate UUID
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
      status: ArticleStatus.queued,
      createdAt: now,
      updatedAt: now,
    );

    await db.insert('articles', article.toMap());
    return article;
  }

  /// Get all articles with optional filters
  Future<List<Article>> getArticles({
    String? status,
    bool? isRead,
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
  /// Checks content.json exists and is valid before returning
  Future<Article?> getArticle(String id) async {
    final db = await DatabaseHelper.database;
    
    final results = await db.query(
      'articles',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (results.isEmpty) return null;

    final article = Article.fromMap(results.first);

    // Self-heal: verify content.json exists and is valid for ready articles
    if (article.status == ArticleStatus.ready) {
      final isValid = await StorageHelper.verifyArticleContent(id);
      
      if (!isValid) {
        // Content is missing or corrupted - mark as failed for retry
        await updateArticleStatus(id, ArticleStatus.failed, 
          errorMessage: 'Content file missing or corrupted');
        article.status = ArticleStatus.failed;
        article.errorMessage = 'Content file missing or corrupted';
      }
    }

    return article;
  }

  /// Update article status with error message
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

    await db.update(
      'articles',
      updates,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Update article fields
  Future<void> updateArticle(String id, Map<String, dynamic> updates) async {
    final db = await DatabaseHelper.database;
    
    updates['updated_at'] = DateTime.now().toIso8601String();
    
    await db.update(
      'articles',
      updates,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Update reading progress
  Future<void> updateReadingProgress(String id, double progress) async {
    final db = await DatabaseHelper.database;
    
    await db.update(
      'articles',
      {
        'reading_progress': progress,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Mark article as read
  Future<void> markAsRead(String id) async {
    final db = await DatabaseHelper.database;
    
    await db.update(
      'articles',
      {
        'is_read': 1,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Toggle favorite status
  Future<void> toggleFavorite(String id) async {
    final db = await DatabaseHelper.database;
    
    await db.rawUpdate('''
      UPDATE articles 
      SET is_favorite = CASE WHEN is_favorite = 1 THEN 0 ELSE 1 END,
          updated_at = ?
      WHERE id = ?
    ''', [DateTime.now().toIso8601String(), id]);
  }

  /// Delete article and its files
  Future<void> deleteArticle(String id) async {
    final db = await DatabaseHelper.database;
    
    // Delete files first
    await StorageHelper.deleteArticleDirectory(id);
    
    // Delete from database
    await db.delete(
      'articles',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Get articles that need to be downloaded
  Future<List<Article>> getQueuedArticles() async {
    return getArticles(
      orderBy: 'created_at ASC',
    ).then((articles) => articles.where((a) => 
      a.status == ArticleStatus.queued ||
      a.status == ArticleStatus.failed ||
      a.status == ArticleStatus.online_only
    ).toList());
  }

  /// Get articles by status
  Future<List<Article>> getArticlesByStatus(ArticleStatus status) async {
    return getArticles(status: status.value);
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

  /// Get storage usage for articles
  Future<int> getStorageUsage() async {
    return await StorageHelper.getStorageUsage();
  }

  /// Get unread articles
  Future<List<Article>> getUnreadArticles() async {
    return getArticles(isRead: false);
  }

  /// Get downloaded articles (status = ready)
  Future<List<Article>> getDownloadedArticles() async {
    return getArticles(status: ArticleStatus.ready.value);
  }

  /// Get favorites
  Future<List<Article>> getFavorites() async {
    final db = await DatabaseHelper.database;
    
    final results = await db.query(
      'articles',
      where: 'is_favorite = ?',
      whereArgs: [1],
      orderBy: 'created_at DESC',
    );

    return results.map((map) => Article.fromMap(map)).toList();
  }

  /// Search articles by title or domain
  Future<List<Article>> searchArticles(String query) async {
    return getArticles(searchQuery: query);
  }
}
