import 'package:sqflite/sqflite.dart' hide Transaction;
import '../../models/transaction.dart';
import '../../services/write_notifier.dart';

mixin LocalDbTransactionsPay {
  Future<Database> get database;

  Future<void> payOpenOrderAtomic({
    required int transactionId,
    required String orderKey,
    required int total,
    required int subtotal,
    required int billDiscount,
    required String discountType,
    required int discountValue,
    required double taxRate,
    required int taxAmount,
    required DateTime createdAt,
    required List<TransactionLine> lines,
    required int cashReceived,
    required int changeAmount,
    required String? tableNumber,
    required String? orderType,
    bool skipSync = false,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.insert('transactions', {
        'id': transactionId,
        'total': total,
        'subtotal': subtotal,
        'bill_discount': billDiscount,
        'discount_type': discountType,
        'discount_value': discountValue,
        'tax_rate': taxRate,
        'tax_amount': taxAmount,
        'created_at': createdAt.toUtc().millisecondsSinceEpoch,
        'is_synced': 0,
        'is_deleted': 0,
        'cash_received': cashReceived,
        'change_amount': changeAmount,
        'table_number': tableNumber,
        'order_type': orderType,
        'parent_order_key': null,
        'is_voided': 0,
      });
      for (final line in lines) {
        await txn.insert('transaction_items', {
          'transaction_id': transactionId,
          'product_id': line.productId,
          'product_name': line.productName,
          'price': line.price,
          'hpp': line.hpp,
          'qty': line.qty,
        });
      }
      await txn.delete('open_order_items',
          where: 'order_key = ?', whereArgs: [orderKey]);
      await txn.delete('open_orders',
          where: 'order_key = ?', whereArgs: [orderKey]);
      await txn.insert(
        'deleted_open_order_keys',
        {
          'order_key': orderKey,
          'deleted_at': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
    if (!skipSync) await WriteNotifier.notify();
  }

  Future<void> payPartialOpenOrderAtomic({
    required int transactionId,
    required String orderKey,
    required int total,
    required int subtotal,
    required int billDiscount,
    required String discountType,
    required int discountValue,
    required double taxRate,
    required int taxAmount,
    required DateTime createdAt,
    required List<TransactionLine> lines,
    required Map<int, int> selectionQtyByItemId,
    required int cashReceived,
    required int changeAmount,
    required String? tableNumber,
    required String? orderType,
    bool skipSync = false,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.insert('transactions', {
        'id': transactionId,
        'total': total,
        'subtotal': subtotal,
        'bill_discount': billDiscount,
        'discount_type': discountType,
        'discount_value': discountValue,
        'tax_rate': taxRate,
        'tax_amount': taxAmount,
        'created_at': createdAt.toUtc().millisecondsSinceEpoch,
        'is_synced': 0,
        'is_deleted': 0,
        'cash_received': cashReceived,
        'change_amount': changeAmount,
        'table_number': tableNumber,
        'order_type': orderType,
        'parent_order_key': orderKey,
        'is_voided': 0,
      });
      for (final line in lines) {
        await txn.insert('transaction_items', {
          'transaction_id': transactionId,
          'product_id': line.productId,
          'product_name': line.productName,
          'price': line.price,
          'hpp': line.hpp,
          'qty': line.qty,
        });
      }
      for (final entry in selectionQtyByItemId.entries) {
        final itemId = entry.key;
        final paidQty = entry.value;
        if (paidQty <= 0) continue;
        final rows = await txn.query('open_order_items',
            where: 'id = ?', whereArgs: [itemId], limit: 1);
        if (rows.isEmpty) continue;
        final currentQty = (rows.first['qty'] as num).toInt();
        final newQty = currentQty - paidQty;
        if (newQty <= 0) {
          await txn.delete('open_order_items',
              where: 'id = ?', whereArgs: [itemId]);
        } else {
          await txn.update('open_order_items', {'qty': newQty},
              where: 'id = ?', whereArgs: [itemId]);
        }
      }
      final remaining = await txn.query('open_order_items',
          where: 'order_key = ?', whereArgs: [orderKey], limit: 1);
      if (remaining.isEmpty) {
        await txn.delete('open_orders',
            where: 'order_key = ?', whereArgs: [orderKey]);
        await txn.insert(
          'deleted_open_order_keys',
          {
            'order_key': orderKey,
            'deleted_at': DateTime.now().millisecondsSinceEpoch,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
    if (!skipSync) await WriteNotifier.notify();
  }
}