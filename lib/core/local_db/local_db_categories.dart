// lib/core/local_db/local_db_categories.dart
import 'package:sqflite/sqflite.dart';
import '../../models/category.dart';

mixin LocalDbCategories {
  Future<Database> get database;

  static Future<void> createTableCategories(Database db) async {
    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        is_synced INTEGER DEFAULT 1,
        is_deleted INTEGER DEFAULT 0
      )
    ''');
  }

  static Future<void> createTableCategoriesLegacy(Database db) async {
    await db.execute(
        'CREATE TABLE IF NOT EXISTS categories (id INTEGER PRIMARY KEY, name TEXT NOT NULL)');
  }

  Future<void> replaceAllCategories(List<Category> categories) async {
    final db = await database;
    await db.transaction((txn) async {
      final unsyncedMaps =
          await txn.query('categories', where: 'is_synced = 0');
      final unsyncedIds = unsyncedMaps.map((m) => m['id'] as int).toSet();
      await txn.delete('categories', where: 'is_synced = 1');
      final batch = txn.batch();
      for (final c in categories) {
        if (unsyncedIds.contains(c.id)) continue;
        batch.insert('categories', c.toDb(),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    });
  }

  Future<List<Category>> getCategories() async {
    final db = await database;
    final maps = await db
        .query('categories', where: 'is_deleted = 0', orderBy: 'id ASC');
    return maps.map((m) => Category.fromDb(m)).toList();
  }

  Future<List<Category>> getUnsyncedCategories() async {
    final db = await database;
    final maps = await db
        .query('categories', where: 'is_synced = 0 AND is_deleted = 0');
    return maps.map((m) => Category.fromDb(m)).toList();
  }

  Future<List<Category>> getDeletedCategories() async {
    final db = await database;
    final maps = await db
        .query('categories', where: 'is_deleted = 1 AND is_synced = 0');
    return maps.map((m) => Category.fromDb(m)).toList();
  }

  Future<void> upsertCategory(Category category) async {
    final db = await database;
    await db.insert('categories', category.toDb(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteCategory(int id) async {
    final db = await database;
    await db.delete('categories', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> markCategoryDeleted(int id) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.update(
        'products',
        {'category_id': null, 'is_synced': 0},
        where: 'category_id = ?',
        whereArgs: [id],
      );
      await txn.update(
        'categories',
        {'is_deleted': 1, 'is_synced': 0},
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }
}