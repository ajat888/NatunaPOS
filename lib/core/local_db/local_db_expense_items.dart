import 'package:sqflite/sqflite.dart';
import '../../models/expense_item.dart';
import '../../services/write_notifier.dart';

mixin LocalDbExpenseItems {
  Future<Database> get database;

  static Future<void> createTableExpenseItems(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS expense_items (
        id INTEGER PRIMARY KEY,
        category_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        is_synced INTEGER DEFAULT 1,
        is_deleted INTEGER DEFAULT 0
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_expense_items_category ON expense_items(category_id)');
  }

  Future<void> replaceAllExpenseItems(List<ExpenseItem> items, {bool skipSync = false}) async {
    final db = await database;
    await db.transaction((txn) async {
      final unsyncedMaps = await txn.query('expense_items', where: 'is_synced = 0');
      final unsyncedIds = unsyncedMaps.map((m) => m['id'] as int).toSet();

      final deletedMaps = await txn.query('expense_items',
          where: 'is_deleted = 1 AND is_synced = 1');
      final deletedIds = deletedMaps.map((m) => m['id'] as int).toSet();

      await txn.delete('expense_items', where: 'is_synced = 1 AND is_deleted = 0');

      final batch = txn.batch();
      for (final it in items) {
        if (unsyncedIds.contains(it.id)) continue;
        if (deletedIds.contains(it.id)) continue;
        batch.insert('expense_items', it.toDb(),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    });
    if (!skipSync) await WriteNotifier.notify();
  }

  Future<List<ExpenseItem>> getExpenseItems() async {
    final db = await database;
    final maps = await db.query('expense_items',
        where: 'is_deleted = 0', orderBy: 'category_id ASC, name ASC');
    return maps.map((m) => ExpenseItem.fromDb(m)).toList();
  }

  Future<List<ExpenseItem>> getInactiveExpenseItems() async {
    final db = await database;
    final maps = await db.query('expense_items',
        where: 'is_deleted = 1', orderBy: 'category_id ASC, name ASC');
    return maps.map((m) => ExpenseItem.fromDb(m)).toList();
  }

  Future<List<ExpenseItem>> getExpenseItemsForInput() async {
    final db = await database;
    final maps = await db.rawQuery('''
      SELECT ei.* FROM expense_items ei
      INNER JOIN expense_categories ec ON ei.category_id = ec.id
      WHERE ei.is_deleted = 0 AND ec.is_deleted = 0
      ORDER BY ec.name ASC, ei.name ASC
    ''');
    return maps.map((m) => ExpenseItem.fromDb(m)).toList();
  }

  Future<List<ExpenseItem>> getUnsyncedExpenseItems() async {
    final db = await database;
    final maps = await db.query('expense_items',
        where: 'is_synced = 0 AND is_deleted = 0');
    return maps.map((m) => ExpenseItem.fromDb(m)).toList();
  }

  Future<List<ExpenseItem>> getDeletedExpenseItems() async {
    final db = await database;
    final maps = await db.query('expense_items',
        where: 'is_deleted = 1 AND is_synced = 0');
    return maps.map((m) => ExpenseItem.fromDb(m)).toList();
  }

  Future<void> upsertExpenseItem(ExpenseItem item, {bool skipSync = false}) async {
    final db = await database;
    await db.insert('expense_items', item.toDb(),
        conflictAlgorithm: ConflictAlgorithm.replace);
    if (!skipSync) await WriteNotifier.notify();
  }

  Future<void> deleteExpenseItemLocal(int id, {bool skipSync = false}) async {
    final db = await database;
    await db.delete('expense_items', where: 'id = ?', whereArgs: [id]);
    if (!skipSync) await WriteNotifier.notify();
  }

  Future<void> markExpenseItemDeleted(int id, {bool skipSync = false}) async {
    final db = await database;
    await db.update('expense_items', {'is_deleted': 1, 'is_synced': 0},
        where: 'id = ?', whereArgs: [id]);
    if (!skipSync) await WriteNotifier.notify();
  }

  Future<void> restoreExpenseItem(int id, {bool skipSync = false}) async {
    final db = await database;
    await db.update('expense_items', {'is_deleted': 0, 'is_synced': 0},
        where: 'id = ?', whereArgs: [id]);
    if (!skipSync) await WriteNotifier.notify();
  }

  Future<void> markExpenseItemSynced(int id, {bool skipSync = false}) async {
    final db = await database;
    await db.update('expense_items', {'is_synced': 1},
        where: 'id = ?', whereArgs: [id]);
    if (!skipSync) await WriteNotifier.notify();
  }

  Future<void> remapExpenseItemCategory(int oldCategoryId, int newCategoryId, {bool skipSync = false}) async {
    final db = await database;
    await db.update(
      'expense_items',
      {'category_id': newCategoryId, 'is_synced': 0},
      where: 'category_id = ?',
      whereArgs: [oldCategoryId],
    );
    if (!skipSync) await WriteNotifier.notify();
  }

  Future<bool> isExpenseItemNameDuplicate(String name, int categoryId, {int? excludeId}) async {
    final db = await database;
    final whereClause = excludeId != null
        ? 'LOWER(name) = ? AND category_id = ? AND is_deleted = 0 AND id != ?'
        : 'LOWER(name) = ? AND category_id = ? AND is_deleted = 0';
    final whereArgsList = excludeId != null
        ? [name.toLowerCase().trim(), categoryId, excludeId]
        : [name.toLowerCase().trim(), categoryId];
    final maps = await db.query('expense_items',
        where: whereClause, whereArgs: whereArgsList, limit: 1);
    return maps.isNotEmpty;
  }
}