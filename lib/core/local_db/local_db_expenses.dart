import 'package:sqflite/sqflite.dart';
import '../../models/expense.dart';

mixin LocalDbExpenses {
  Future<Database> get database;

  static Future<void> createTableExpenses(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS expenses (
        id INTEGER PRIMARY KEY,
        item_id INTEGER,
        item_name TEXT NOT NULL,
        category_id INTEGER,
        category_name TEXT NOT NULL,
        amount INTEGER NOT NULL,
        description TEXT,
        created_at INTEGER NOT NULL,
        created_by TEXT NOT NULL,
        is_synced INTEGER DEFAULT 0,
        is_deleted INTEGER DEFAULT 0
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_expenses_created ON expenses(created_at)');
  }

  Future<void> insertExpense(Expense expense) async {
    final db = await database;
    await db.insert('expenses', expense.toDb(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Expense>> getExpenses({int limit = 200}) async {
    final db = await database;
    final maps = await db.query('expenses',
        where: 'is_deleted = 0', orderBy: 'created_at DESC', limit: limit);
    return maps.map((m) => Expense.fromDb(m)).toList();
  }

  Future<int> getTodayExpenseTotal() async {
    final db = await database;
    final now = DateTime.now();
    final startLocal = DateTime(now.year, now.month, now.day);
    final endLocal = DateTime(now.year, now.month, now.day + 1);
    final result = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) AS t FROM expenses
      WHERE is_deleted = 0 AND created_at >= ? AND created_at < ?
    ''', [
      startLocal.toUtc().millisecondsSinceEpoch,
      endLocal.toUtc().millisecondsSinceEpoch
    ]);
    final row = result.first;
    return (row['t'] as num?)?.toInt() ?? 0;
  }

  Future<List<Expense>> getUnsyncedExpenses() async {
    final db = await database;
    final maps = await db.query('expenses',
        where: 'is_synced = 0 AND is_deleted = 0', orderBy: 'created_at ASC');
    return maps.map((m) => Expense.fromDb(m)).toList();
  }

  Future<List<Expense>> getDeletedExpenses() async {
    final db = await database;
    final maps = await db.query('expenses',
        where: 'is_deleted = 1 AND is_synced = 0');
    return maps.map((m) => Expense.fromDb(m)).toList();
  }

  Future<Set<int>> getUnsyncedExpenseIds() async {
    final db = await database;
    final maps = await db.query('expenses',
        columns: ['id'], where: 'is_synced = 0');
    return maps.map((m) => m['id'] as int).toSet();
  }

  Future<void> markExpenseDeleted(int id) async {
    final db = await database;
    await db.update('expenses', {'is_deleted': 1, 'is_synced': 0},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<void> markExpenseSyncedAndDeleted(int id) async {
    final db = await database;
    await db.update('expenses', {'is_synced': 1},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<void> replaceExpenseId({
    required int oldId,
    required int newId,
    int? newItemId,
    int? newCategoryId,
  }) async {
    final db = await database;
    final values = <String, dynamic>{'id': newId, 'is_synced': 1};
    if (newItemId != null) values['item_id'] = newItemId;
    if (newCategoryId != null) values['category_id'] = newCategoryId;
    await db.update('expenses', values, where: 'id = ?', whereArgs: [oldId]);
  }

  Future<void> upsertPulledExpense(Expense expense) async {
    final db = await database;
    await db.insert('expenses', expense.copyWith(isSynced: true).toDb(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }
}