# Module: Repository

## Overview

The Repository module provides data access abstraction for articles. It handles CRUD operations, self-heal logic, and query builders.

## Architecture

```
┌─────────────────────────────────────────────────────┐
│              ArticleRepository                       │
│  - CRUD operations                                   │
│  - Self-heal on read                                 │
│  - Query builders                                    │
│  - Duplicate detection                               │
└──────────────────────┬──────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────┐
│              DatabaseHelper                          │
│  - SQLite singleton                                  │
│  - Schema creation                                   │
│  - Migrations                                        │
│  - Startup sanitization                              │
└──────────────────────┬──────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────┐
│              SQLite Database                         │
│  - articles table                                    │
│  - Indexes                                           │
└─────────────────────────────────────────────────────┘
```

---

## ArticleRepository

### File: `lib/repositories/article_repository.dart`

### Responsibilities

1. Insert new articles
2. Query articles with filters
3. Update article status and fields
4. Delete articles and their files
5. Self-heal on read (verify content integrity)
6. Provide counts and statistics

---

## CRUD Operations

### Insert Article

```dart
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
```

### Key Behaviors

1. **Canonicalize URL** — Strip tracking params (utm_*, fbclid, etc.)
2. **Duplicate check** — By `canonical_url` (UNIQUE constraint)
3. **Return existing** — If duplicate, return existing article (not null)
4. **UUID generation** — Always UUID v4 for article ID
5. **Initial status** — Always `queued`

---

### Get Articles

```dart
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
```

### Query Options

| Parameter | Type | Description |
|---|---|---|
| `status` | `String?` | Filter by ArticleStatus value |
| `isRead` | `bool?` | Filter by read status |
| `searchQuery` | `String?` | Search title and domain |
| `orderBy` | `String?` | SQL ORDER BY clause |

### Default Order

- `created_at DESC` — Newest first

---

### Get Single Article (with Self-Heal)

```dart
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
```

### Self-Heal Logic

When fetching an article with `status = ready`:
1. Verify `content.json` exists on disk
2. Verify `content.json` is valid JSON
3. If invalid → mark as `failed` with error message
4. Return article (now with `failed` status)

This handles:
- Corrupted files
- Missing files (deleted externally)
- Orphan database rows

---

### Update Article Status

```dart
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
```

### Key Behaviors

1. **Update timestamp** — Always update `updated_at`
2. **Optional error message** — For `failed`/`online_only` status
3. **Status value** — Uses `ArticleStatus.value` (string name)

---

### Update Article Fields

```dart
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
```

### Usage

```dart
await repository.updateArticle(articleId, {
  'content_path': contentPath,
  'title': result.title ?? article.title,
  'author': result.author,
  'excerpt': result.excerpt,
  'cover_image_path': result.coverImage,
  'status': ArticleStatus.ready.value,
});
```

---

### Update Reading Progress

```dart
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
```

### Format

- `double` value between 0.0 and 1.0
- `0.0` = start of article
- `1.0` = end of article

---

### Mark as Read

```dart
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
```

---

### Toggle Favorite

```dart
Future<void> toggleFavorite(String id) async {
  final db = await DatabaseHelper.database;
  
  await db.rawUpdate('''
    UPDATE articles 
    SET is_favorite = CASE WHEN is_favorite = 1 THEN 0 ELSE 1 END,
        updated_at = ?
    WHERE id = ?
  ''', [DateTime.now().toIso8601String(), id]);
}
```

### Implementation

Uses SQL `CASE` statement to toggle:
- If `is_favorite = 1` → set to `0`
- If `is_favorite = 0` → set to `1`

---

### Delete Article

```dart
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
```

### Deletion Order

1. **Delete files** — `/articles/{id}/` and `/articles/{id}.tmp/`
2. **Delete database row** — From `articles` table

This ensures no orphan files remain.

---

## Query Helpers

### Get Queued Articles

```dart
Future<List<Article>> getQueuedArticles() async {
  return getArticles(
    orderBy: 'created_at ASC',
  ).then((articles) => articles.where((a) => 
    a.status == ArticleStatus.queued ||
    a.status == ArticleStatus.failed ||
    a.status == ArticleStatus.online_only
  ).toList());
}
```

### Get Articles by Status

```dart
Future<List<Article>> getArticlesByStatus(ArticleStatus status) async {
  return getArticles(status: status.value);
}
```

### Get Unread Articles

```dart
Future<List<Article>> getUnreadArticles() async {
  return getArticles(isRead: false);
}
```

### Get Downloaded Articles

```dart
Future<List<Article>> getDownloadedArticles() async {
  return getArticles(status: ArticleStatus.ready.value);
}
```

### Get Favorites

```dart
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
```

### Search Articles

```dart
Future<List<Article>> searchArticles(String query) async {
  return getArticles(searchQuery: query);
}
```

---

## Statistics

### Get Article Count by Status

```dart
Future<int> getArticleCountByStatus(ArticleStatus status) async {
  final db = await DatabaseHelper.database;
  
  final result = await db.rawQuery(
    'SELECT COUNT(*) as count FROM articles WHERE status = ?',
    [status.value],
  );
  
  return result.first['count'] as int;
}
```

### Get Total Article Count

```dart
Future<int> getTotalArticleCount() async {
  final db = await DatabaseHelper.database;
  
  final result = await db.rawQuery('SELECT COUNT(*) as count FROM articles');
  return result.first['count'] as int;
}
```

### Get Storage Usage

```dart
Future<int> getStorageUsage() async {
  return await StorageHelper.getStorageUsage();
}
```

---

## Database Schema

### articles Table

```sql
CREATE TABLE articles (
    id TEXT PRIMARY KEY,
    original_url TEXT NOT NULL,
    canonical_url TEXT NOT NULL UNIQUE,
    title TEXT NOT NULL,
    domain TEXT NOT NULL,
    author TEXT,
    excerpt TEXT,
    cover_image_path TEXT,
    content_path TEXT,
    status TEXT NOT NULL DEFAULT 'queued',
    extractor_version INTEGER DEFAULT 1,
    is_read INTEGER DEFAULT 0,
    is_favorite INTEGER DEFAULT 0,
    reading_progress REAL DEFAULT 0.0,
    error_message TEXT,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
);
```

### Indexes

```sql
CREATE INDEX idx_articles_status ON articles(status);
CREATE INDEX idx_articles_is_read ON articles(is_read);
CREATE INDEX idx_articles_canonical_url ON articles(canonical_url);
CREATE INDEX idx_articles_domain ON articles(domain);
```

### Migration Strategy

- Use `PRAGMA user_version` for version tracking
- Currently at version 1 (base schema)
- Each migration preserves existing data
- Migrations are in `DatabaseHelper._onUpgrade()`

---

## Error Handling

### Database Errors

```dart
try {
  await db.insert('articles', article.toMap());
} catch (e) {
  // Log error, return null or throw
  return null;
}
```

### Self-Heal Errors

```dart
if (article.status == ArticleStatus.ready) {
  final isValid = await StorageHelper.verifyArticleContent(id);
  
  if (!isValid) {
    // Mark as failed, don't throw
    await updateArticleStatus(id, ArticleStatus.failed, 
      errorMessage: 'Content file missing or corrupted');
  }
}
```

### File Deletion Errors

```dart
try {
  await StorageHelper.deleteArticleDirectory(id);
  await db.delete('articles', where: 'id = ?', whereArgs: [id]);
} catch (e) {
  // Log error, don't crash
}
```

---

## Testing

### Test Cases

1. **Insert article** — New URL → queued status
2. **Duplicate detection** — Same canonical URL → returns existing
3. **Get article** — Returns article with self-heal
4. **Self-heal** — Corrupted content → marks as failed
5. **Update status** — Status changes correctly
6. **Update fields** — Metadata updates correctly
7. **Delete article** — Files and DB row removed
8. **Search** — Title and domain search works
9. **Filters** — Status and read filters work
10. **Statistics** — Counts are accurate

### Performance

- Indexes on frequently queried columns
- `canonical_url` has UNIQUE constraint
- `status` and `is_read` indexed for filtering
