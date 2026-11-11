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

  Future<List<Map<String, dynamic>>> getProductPerformanceBetween(
      DateTime from, DateTime to) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT
        ti.product_id AS product_id,
        ti.product_name AS product_name,
        ti.price AS unit_price,
        ti.hpp AS unit_hpp,
        SUM(ti.qty) AS qty_sold,
        SUM(ti.price * ti.qty) AS revenue,
        SUM(ti.hpp * ti.qty) AS total_hpp
      FROM transaction_items ti
      INNER JOIN transactions t ON ti.transaction_id = t.id
      WHERE t.is_deleted = 0 AND t.is_voided = 0
        AND t.created_at >= ? AND t.created_at < ?
      GROUP BY ti.product_id, ti.product_name, ti.price, ti.hpp
      ORDER BY SUM(ti.price * ti.qty) DESC
    ''', [
      from.toUtc().millisecondsSinceEpoch,
      to.toUtc().millisecondsSinceEpoch,
    ]);
    return rows.map((r) {
      final unitPrice = (r['unit_price'] as num?)?.toInt() ?? 0;
      final unitHpp = (r['unit_hpp'] as num?)?.toInt() ?? 0;
      final qty = (r['qty_sold'] as num?)?.toInt() ?? 0;
      final revenue = (r['revenue'] as num?)?.toInt() ?? 0;
      final totalHpp = (r['total_hpp'] as num?)?.toInt() ?? 0;
      return <String, dynamic>{
        'product_id': (r['product_id'] as num?)?.toInt(),
        'name': (r['product_name'] as String?) ?? '',
        'unit_price': unitPrice,
        'unit_hpp': unitHpp,
        'unit_profit': unitPrice - unitHpp,
        'qty_sold': qty,
        'revenue': revenue,
        'total_hpp': totalHpp,
        'profit': revenue - totalHpp,
      };
    }).toList();
  }

  Future<List<Map<String, dynamic>>> getDailySalesBreakdown(
      DateTime from, DateTime to) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT
        DATE(created_at / 1000, 'unixepoch', 'localtime') AS day,
        COUNT(*) AS tx_count,
        COALESCE(SUM(total), 0) AS sales
      FROM transactions
      WHERE is_deleted = 0 AND is_voided = 0
        AND created_at >= ? AND created_at < ?
      GROUP BY day
      ORDER BY day ASC
    ''', [
      from.toUtc().millisecondsSinceEpoch,
      to.toUtc().millisecondsSinceEpoch,
    ]);
    return rows
        .map((r) => <String, dynamic>{
              'date': (r['day'] as String?) ?? '',
              'tx_count': (r['tx_count'] as num?)?.toInt() ?? 0,
              'sales': (r['sales'] as num?)?.toInt() ?? 0,
            })
        .toList();
  }
}