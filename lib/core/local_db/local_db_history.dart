import 'package:sqflite/sqflite.dart' hide Transaction;
import '../../models/expense.dart';
import '../../models/transaction.dart';

mixin LocalDbHistory {
  Future<Database> get database;

  Future<List<Transaction>> getSalesWithItemsBetween(
      DateTime from, DateTime to) async {
    final db = await database;
    final rows = await db.rawQuery(
      'SELECT t.*, ti.id AS item_id, ti.product_id, ti.product_name, '
      'ti.price, ti.hpp, ti.qty '
      'FROM transactions t '
      'LEFT JOIN transaction_items ti ON ti.transaction_id = t.id '
      'WHERE t.is_deleted = 0 AND t.created_at >= ? AND t.created_at < ? '
      'ORDER BY t.created_at DESC, t.id ASC, ti.id ASC',
      [from.toUtc().millisecondsSinceEpoch, to.toUtc().millisecondsSinceEpoch],
    );
    final order = <int>[];
    final headers = <int, Map<String, dynamic>>{};
    final itemsByTx = <int, List<TransactionItem>>{};
    for (final row in rows) {
      final txId = row['id'] as int;
      if (!headers.containsKey(txId)) {
        headers[txId] = row;
        order.add(txId);
      }
      final itemId = row['item_id'] as int?;
      if (itemId != null) {
        itemsByTx.putIfAbsent(txId, () => []).add(TransactionItem.fromDb({
              'id': itemId,
              'transaction_id': txId,
              'product_id': row['product_id'],
              'product_name': row['product_name'],
              'price': row['price'],
              'hpp': row['hpp'],
              'qty': row['qty'],
            }));
      }
    }
    return order
        .map((id) => Transaction.fromDb(headers[id]!, itemsByTx[id] ?? []))
        .toList();
  }

  Future<List<Expense>> getExpensesInRange(DateTime from, DateTime to) async {
    final db = await database;
    final maps = await db.query(
      'expenses',
      where: 'is_deleted = 0 AND created_at >= ? AND created_at < ?',
      whereArgs: [
        from.toUtc().millisecondsSinceEpoch,
        to.toUtc().millisecondsSinceEpoch,
      ],
      orderBy: 'created_at DESC',
    );
    return maps.map((m) => Expense.fromDb(m)).toList();
  }
}