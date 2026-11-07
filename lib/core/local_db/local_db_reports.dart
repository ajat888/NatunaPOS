// lib/core/local_db/local_db_reports.dart
import 'package:sqflite/sqflite.dart' hide Transaction;
import '../../models/expense.dart';
import '../../models/transaction.dart';

mixin LocalDbReports {
  Future<Database> get database;

  Future<Map<String, int>> getSalesSummaryBetween(
      DateTime from, DateTime to) async {
    final db = await database;
    final r = await db.rawQuery(
      'SELECT COUNT(*) AS c, COALESCE(SUM(total), 0) AS t FROM transactions '
      'WHERE is_deleted = 0 AND is_voided = 0 '
      'AND created_at >= ? AND created_at < ?',
      [from.toUtc().millisecondsSinceEpoch, to.toUtc().millisecondsSinceEpoch],
    );
    final row = r.first;
    return {
      'count': (row['c'] as num?)?.toInt() ?? 0,
      'total': (row['t'] as num?)?.toInt() ?? 0,
    };
  }

  Future<int> getHppBetween(DateTime from, DateTime to) async {
    final db = await database;
    final r = await db.rawQuery(
      'SELECT COALESCE(SUM(ti.hpp * ti.qty), 0) AS h '
      'FROM transaction_items ti '
      'INNER JOIN transactions t ON ti.transaction_id = t.id '
      'WHERE t.is_deleted = 0 AND t.is_voided = 0 '
      'AND t.created_at >= ? AND t.created_at < ?',
      [from.toUtc().millisecondsSinceEpoch, to.toUtc().millisecondsSinceEpoch],
    );
    return (r.first['h'] as num?)?.toInt() ?? 0;
  }

  Future<int> getCashExpectedBetween(DateTime from, DateTime to) async {
    final db = await database;
    final r = await db.rawQuery(
      'SELECT COALESCE(SUM(cash_received - change_amount), 0) AS c '
      'FROM transactions '
      'WHERE is_deleted = 0 AND is_voided = 0 '
      'AND created_at >= ? AND created_at < ?',
      [from.toUtc().millisecondsSinceEpoch, to.toUtc().millisecondsSinceEpoch],
    );
    return (r.first['c'] as num?)?.toInt() ?? 0;
  }

  Future<Map<String, int>> getVoidTransactionsSummaryBetween(
      DateTime from, DateTime to) async {
    final db = await database;
    final r = await db.rawQuery(
      'SELECT COUNT(*) AS c, COALESCE(SUM(total), 0) AS t '
      'FROM transactions '
      'WHERE is_deleted = 0 AND is_voided = 1 '
      'AND created_at >= ? AND created_at < ?',
      [from.toUtc().millisecondsSinceEpoch, to.toUtc().millisecondsSinceEpoch],
    );
    final row = r.first;
    return {
      'count': (row['c'] as num?)?.toInt() ?? 0,
      'total': (row['t'] as num?)?.toInt() ?? 0,
    };
  }

  Future<Map<String, int>> getExpenseSummaryBetween(
      DateTime from, DateTime to) async {
    final db = await database;
    final r = await db.rawQuery(
      'SELECT COUNT(*) AS c, COALESCE(SUM(amount), 0) AS t '
      'FROM expenses WHERE is_deleted = 0 '
      'AND created_at >= ? AND created_at < ?',
      [from.toUtc().millisecondsSinceEpoch, to.toUtc().millisecondsSinceEpoch],
    );
    final row = r.first;
    return {
      'count': (row['c'] as num?)?.toInt() ?? 0,
      'total': (row['t'] as num?)?.toInt() ?? 0,
    };
  }

  Future<List<Transaction>> getTransactionsBetween(
      DateTime from, DateTime to) async {
    final db = await database;
    final txMaps = await db.query(
      'transactions',
      where: 'is_deleted = 0 AND created_at >= ? AND created_at < ?',
      whereArgs: [
        from.toUtc().millisecondsSinceEpoch,
        to.toUtc().millisecondsSinceEpoch,
      ],
      orderBy: 'created_at DESC',
      limit: 200,
    );
    if (txMaps.isEmpty) return [];
    final txIds = txMaps.map((m) => m['id'] as int).toList();
    final ph = List.filled(txIds.length, '?').join(',');
    final itemMaps = await db.query(
      'transaction_items',
      where: 'transaction_id IN ($ph)',
      whereArgs: txIds,
    );
    final itemsByTx = <int, List<TransactionItem>>{};
    for (final m in itemMaps) {
      final item = TransactionItem.fromDb(m);
      itemsByTx.putIfAbsent(item.transactionId, () => []).add(item);
    }
    return txMaps.map((m) {
      final id = m['id'] as int;
      return Transaction.fromDb(m, itemsByTx[id] ?? []);
    }).toList();
  }

  Future<List<Expense>> getExpensesBetween(
      DateTime from, DateTime to) async {
    final db = await database;
    final maps = await db.query(
      'expenses',
      where: 'is_deleted = 0 AND created_at >= ? AND created_at < ?',
      whereArgs: [
        from.toUtc().millisecondsSinceEpoch,
        to.toUtc().millisecondsSinceEpoch,
      ],
      orderBy: 'created_at DESC',
      limit: 200,
    );
    return maps.map((m) => Expense.fromDb(m)).toList();
  }
}