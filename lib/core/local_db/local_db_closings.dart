// lib/core/local_db/local_db_closings.dart
import 'package:sqflite/sqflite.dart';
import '../../models/daily_closing.dart';

mixin LocalDbClosings {
  Future<Database> get database;

  static Future<void> createTableDailyClosings(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS daily_closings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        closing_date TEXT NOT NULL UNIQUE,
        total_sales INTEGER NOT NULL,
        total_transactions INTEGER NOT NULL,
        total_hpp INTEGER NOT NULL,
        total_expenses INTEGER NOT NULL,
        total_void_amount INTEGER NOT NULL,
        void_count INTEGER NOT NULL,
        cash_expected INTEGER NOT NULL,
        cash_actual INTEGER NOT NULL,
        cash_difference INTEGER NOT NULL,
        closing_note TEXT,
        closed_by TEXT NOT NULL,
        closed_at INTEGER NOT NULL
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_daily_closings_date ON daily_closings(closing_date DESC)');
  }

  static Future<void> upgradeDailyClosingsV15(Database db) async {
    await createTableDailyClosings(db);
  }

  Future<void> insertDailyClosing(DailyClosing closing) async {
    final db = await database;
    await db.insert('daily_closings', closing.toDb(),
        conflictAlgorithm: ConflictAlgorithm.abort);
  }

  Future<DailyClosing?> getDailyClosingByDate(String closingDate) async {
    final db = await database;
    final maps = await db.query('daily_closings',
        where: 'closing_date = ?', whereArgs: [closingDate], limit: 1);
    if (maps.isEmpty) return null;
    return DailyClosing.fromDb(maps.first);
  }

  Future<List<DailyClosing>> getRecentDailyClosings({int limit = 30}) async {
    final db = await database;
    final maps = await db.query('daily_closings',
        orderBy: 'closing_date DESC', limit: limit);
    return maps.map((m) => DailyClosing.fromDb(m)).toList();
  }

  Future<bool> isDateClosed(String closingDate) async {
    final db = await database;
    final r = await db.query('daily_closings',
        columns: ['id'],
        where: 'closing_date = ?',
        whereArgs: [closingDate],
        limit: 1);
    return r.isNotEmpty;
  }
}