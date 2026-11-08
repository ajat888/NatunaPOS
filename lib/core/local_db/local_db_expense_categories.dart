import 'package:sqflite/sqflite.dart';
import '../../models/expense_category.dart';
import '../../services/write_notifier.dart';

mixin LocalDbExpenseCategories {
  Future<Database> get database;

  static Future<void> createTableExpenseCategories(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS expense_categories (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        is_synced INTEGER DEFAULT 1,
        is_deleted INTEGER DEFAULT 0
      )
    ''');
  }

  Future<void> replaceAllExpenseCategories(List<ExpenseCategory> categories, {bool skipSync = false}) async {
    final db = await database;
    await db.transaction((txn) async {
      final unsyncedMaps = await txn.query('expense_categories', where: 'is_synced = 0');
      final unsyncedIds = unsyncedMaps.map((m) => m['id'] as int).toSet();

      final deletedMaps = await txn.query('expense_categories',
          where: 'is_deleted = 1 AND is_synced = 1');
      final deletedIds = deletedMaps.map((m) => m['id'] as int).toSet();

      await txn.delete('expense_categories', where: 'is_synced = 1 AND is_deleted = 0');

      final batch = txn.batch();
      for (final c in categories) {
        if (unsyncedIds.contains(c.id)) continue;
        if (deletedIds.contains(c.id)) continue;
        batch.insert('expense_categories', c.toDb(),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    });
    if (!skipSync) await WriteNotifier.notify();
  }

  Future<List<ExpenseCategory>> getExpenseCategories() async {
    final db = await database;
    final maps = await db.query('expense_categories',
        where: 'is_deleted = 0', orderBy: 'name ASC');
    return maps.map((m) => ExpenseCategory.fromDb(m)).toList();
  }

  Future<List<ExpenseCategory>> getInactiveExpenseCategories() async {
    final db = await database;
    final maps = await db.query('expense_categories',
        where: 'is_deleted = 1', orderBy: 'name ASC');
    return maps.map((m) => ExpenseCategory.fromDb(m)).toList();
  }

  Future<List<ExpenseCategory>> getUnsyncedExpenseCategories() async {
    final db = await database;
    final maps = await db.query('expense_categories',
        where: 'is_synced = 0 AND is_deleted = 0');
    return maps.map((m) => ExpenseCategory.fromDb(m)).toList();
  }

  Future<List<ExpenseCategory>> getDeletedExpenseCategories() async {
    final db = await database;
    final maps = await db.query('expense_categories',
        where: 'is_deleted = 1 AND is_synced = 0');
    return maps.map((m) => ExpenseCategory.fromDb(m)).toList();
  }

  Future<void> upsertExpenseCategory(ExpenseCategory category, {bool skipSync = false}) async {
    final db = await database;
    await db.insert('expense_categories', category.toDb(),
        conflictAlgorithm: ConflictAlgorithm.replace);
    if (!skipSync) await WriteNotifier.notify();
  }

  Future<void> deleteExpenseCategoryLocal(int id, {bool skipSync = false}) async {
    final db = await database;
    await db.delete('expense_categories', where: 'id = ?', whereArgs: [id]);
    if (!skipSync) await WriteNotifier.notify();
  }

  Future<void> markExpenseCategoryDeleted(int id, {bool skipSync = false}) async {
    final db = await database;
    await db.update('expense_categories', {'is_deleted': 1, 'is_synced': 0},
        where: 'id = ?', whereArgs: [id]);
    if (!skipSync) await WriteNotifier.notify();
  }

  Future<void> restoreExpenseCategory(int id, {bool skipSync = false}) async {
    final db = await database;
    await db.update('expense_categories', {'is_deleted': 0, 'is_synced': 0},
        where: 'id = ?', whereArgs: [id]);
    if (!skipSync) await WriteNotifier.notify();
  }

  Future<void> markExpenseCategorySynced(int id, {bool skipSync = false}) async {
    final db = await database;
    await db.update('expense_categories', {'is_synced': 1},
        where: 'id = ?', whereArgs: [id]);
    if (!skipSync) await WriteNotifier.notify();
  }

  Future<bool> isExpenseCategoryNameDuplicate(String name, {int? excludeId}) async {
    final db = await database;
    final whereClause = excludeId != null
        ? 'LOWER(name) = ? AND is_deleted = 0 AND id != ?'
        : 'LOWER(name) = ? AND is_deleted = 0';
    final whereArgsList = excludeId != null
        ? [name.toLowerCase().trim(), excludeId]
        : [name.toLowerCase().trim()];
    final maps = await db.query('expense_categories',
        where: whereClause, whereArgs: whereArgsList, limit: 1);
    return maps.isNotEmpty;
  }
}