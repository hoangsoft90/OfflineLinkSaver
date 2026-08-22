import 'package:uuid/uuid.dart';
import '../core/database/database_helper.dart';
import '../models/category.dart';

class CategoryRepository {
  static const _uuid = Uuid();

  /// Get all categories ordered by sort_order
  Future<List<Category>> getAll() async {
    final db = await DatabaseHelper.database;
    final results = await db.query(
      'categories',
      orderBy: 'sort_order ASC, name ASC',
    );
    return results.map((map) => Category.fromMap(map)).toList();
  }

  /// Get category by ID
  Future<Category?> getById(String id) async {
    final db = await DatabaseHelper.database;
    final results = await db.query(
      'categories',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (results.isEmpty) return null;
    return Category.fromMap(results.first);
  }

  /// Create new category
  Future<Category> create(String name, {String color = '#2196F3'}) async {
    final db = await DatabaseHelper.database;
    final id = _uuid.v4();
    final now = DateTime.now();

    // Get next sort order
    final maxOrder = await db.rawQuery('SELECT MAX(sort_order) as max_order FROM categories');
    final nextOrder = (maxOrder.first['max_order'] as int? ?? 0) + 1;

    final category = Category(
      id: id,
      name: name,
      color: color,
      sortOrder: nextOrder,
      createdAt: now,
    );

    await db.insert('categories', category.toMap());
    return category;
  }

  /// Update category
  Future<void> update(String id, {String? name, String? color, int? sortOrder}) async {
    final db = await DatabaseHelper.database;
    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    if (color != null) updates['color'] = color;
    if (sortOrder != null) updates['sort_order'] = sortOrder;

    if (updates.isNotEmpty) {
      await db.update('categories', updates, where: 'id = ?', whereArgs: [id]);
    }
  }

  /// Delete category (articles with this category will be set to null)
  Future<void> delete(String id) async {
    final db = await DatabaseHelper.database;
    // Unset category from articles
    await db.rawUpdate(
      'UPDATE articles SET category_id = NULL WHERE category_id = ?',
      [id],
    );
    await db.delete('categories', where: 'id = ?', whereArgs: [id]);
  }

  /// Get article count per category
  Future<Map<String, int>> getArticleCounts() async {
    final db = await DatabaseHelper.database;
    final results = await db.rawQuery('''
      SELECT category_id, COUNT(*) as count 
      FROM articles 
      WHERE category_id IS NOT NULL
      GROUP BY category_id
    ''');
    final counts = <String, int>{};
    for (final row in results) {
      final catId = row['category_id'] as String?;
      if (catId != null) {
        counts[catId] = row['count'] as int;
      }
    }
    return counts;
  }
}
