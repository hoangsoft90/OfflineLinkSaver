import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static Database? _database;
  static const String _dbName = 'offline_link_saver.db';
  static const int _currentVersion = 1;

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
      )
    ''');

    // Index for faster queries
    await db.execute('CREATE INDEX idx_articles_status ON articles(status)');
    await db.execute('CREATE INDEX idx_articles_is_read ON articles(is_read)');
    await db.execute('CREATE INDEX idx_articles_canonical_url ON articles(canonical_url)');
    await db.execute('CREATE INDEX idx_articles_domain ON articles(domain)');
  }

  static Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Migration strategy: use PRAGMA user_version for future versions
    // For now, v1 is the base schema
  }

  // Startup sanitization - MUST run every time app opens
  // Resets stuck items from downloading/processing to queued
  // This handles cases where OS killed the process mid-download
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
