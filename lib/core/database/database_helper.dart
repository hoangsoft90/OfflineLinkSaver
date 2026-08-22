import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static Database? _database;
  static const String _dbName = 'offline_link_saver.db';
  static const int _currentVersion = 2;

  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  static Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), _dbName);
    return await openDatabase(
      path,
      version: _currentVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  static Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE categories (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        color TEXT DEFAULT '#2196F3',
        sort_order INTEGER DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
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
        category_id TEXT,
        status TEXT NOT NULL DEFAULT 'queued',
        extractor_version INTEGER DEFAULT 1,
        is_read INTEGER DEFAULT 0,
        is_favorite INTEGER DEFAULT 0,
        reading_progress REAL DEFAULT 0.0,
        error_message TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Indexes
    await db.execute('CREATE INDEX idx_articles_status ON articles(status)');
    await db.execute('CREATE INDEX idx_articles_is_read ON articles(is_read)');
    await db.execute('CREATE INDEX idx_articles_canonical_url ON articles(canonical_url)');
    await db.execute('CREATE INDEX idx_articles_domain ON articles(domain)');
    await db.execute('CREATE INDEX idx_articles_category ON articles(category_id)');
    await db.execute('CREATE INDEX idx_articles_is_favorite ON articles(is_favorite)');

    // Seed default categories
    final now = DateTime.now().toIso8601String();
    await db.insert('categories', {
      'id': 'cat_news', 'name': 'News', 'color': '#2196F3',
      'sort_order': 0, 'created_at': now,
    });
    await db.insert('categories', {
      'id': 'cat_tech', 'name': 'Technology', 'color': '#4CAF50',
      'sort_order': 1, 'created_at': now,
    });
    await db.insert('categories', {
      'id': 'cat_tutorial', 'name': 'Tutorial', 'color': '#FF9800',
      'sort_order': 2, 'created_at': now,
    });
  }

  static Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Create categories table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS categories (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          color TEXT DEFAULT '#2196F3',
          sort_order INTEGER DEFAULT 0,
          created_at TEXT NOT NULL
        )
      ''');

      // Add category_id to articles if not exists
      final columns = await db.rawQuery('PRAGMA table_info(articles)');
      final hasCategoryId = columns.any((col) => col['name'] == 'category_id');
      if (!hasCategoryId) {
        await db.execute('ALTER TABLE articles ADD COLUMN category_id TEXT');
      }

      // Add indexes
      await db.execute('CREATE INDEX IF NOT EXISTS idx_articles_category ON articles(category_id)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_articles_is_favorite ON articles(is_favorite)');

      // Seed default categories
      final now = DateTime.now().toIso8601String();
      final existing = await db.query('categories');
      if (existing.isEmpty) {
        await db.insert('categories', {
          'id': 'cat_news', 'name': 'News', 'color': '#2196F3',
          'sort_order': 0, 'created_at': now,
        });
        await db.insert('categories', {
          'id': 'cat_tech', 'name': 'Technology', 'color': '#4CAF50',
          'sort_order': 1, 'created_at': now,
        });
        await db.insert('categories', {
          'id': 'cat_tutorial', 'name': 'Tutorial', 'color': '#FF9800',
          'sort_order': 2, 'created_at': now,
        });
      }
    }
  }

  // Startup sanitization - resets stuck items
  static Future<void> startupSanitization(Database db) async {
    await db.rawUpdate('''
      UPDATE articles 
      SET status = 'queued', updated_at = ?
      WHERE status IN ('downloading', 'processing')
    ''', [DateTime.now().toIso8601String()]);
  }

  static Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}
