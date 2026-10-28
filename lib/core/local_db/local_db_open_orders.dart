// lib/core/local_db/local_db_open_orders.dart
import 'package:sqflite/sqflite.dart';
import '../../models/open_order.dart';

mixin LocalDbOpenOrders {
  Future<Database> get database;

  static Future<void> createTableOpenOrders(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS open_orders (
        order_key TEXT PRIMARY KEY,
        order_type TEXT NOT NULL,
        table_number INTEGER,
        created_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS open_order_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        order_key TEXT NOT NULL,
        product_id INTEGER,
        product_name TEXT NOT NULL,
        price INTEGER NOT NULL,
        hpp INTEGER NOT NULL,
        qty INTEGER NOT NULL
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_open_items_key ON open_order_items(order_key)');
  }

  Future<List<OpenOrder>> getOpenOrders() async {
    final db = await database;
    final orders = await db.query('open_orders',
        orderBy: 'order_type ASC, table_number ASC, created_at ASC');
    if (orders.isEmpty) return [];
    final keys = orders.map((o) => o['order_key'] as String).toList();
    final placeholders = List.filled(keys.length, '?').join(',');
    final itemMaps = await db.query(
      'open_order_items',
      where: 'order_key IN ($placeholders)',
      whereArgs: keys,
      orderBy: 'id ASC',
    );
    final itemsByKey = <String, List<OpenOrderItem>>{};
    for (final m in itemMaps) {
      final item = OpenOrderItem.fromDb(m);
      itemsByKey.putIfAbsent(item.orderKey, () => []).add(item);
    }
    return orders.map((m) {
      final key = m['order_key'] as String;
      return OpenOrder(
        orderKey: key,
        orderType: m['order_type'] as String,
        tableNumber: (m['table_number'] as num?)?.toInt(),
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(m['created_at'] as int),
        items: itemsByKey[key] ?? [],
      );
    }).toList();
  }

  Future<OpenOrder?> getOpenOrder(String orderKey) async {
    final db = await database;
    final orders = await db.query('open_orders',
        where: 'order_key = ?', whereArgs: [orderKey], limit: 1);
    if (orders.isEmpty) return null;
    final m = orders.first;
    final itemMaps = await db.query('open_order_items',
        where: 'order_key = ?', whereArgs: [orderKey], orderBy: 'id ASC');
    return OpenOrder(
      orderKey: m['order_key'] as String,
      orderType: m['order_type'] as String,
      tableNumber: (m['table_number'] as num?)?.toInt(),
      createdAt: DateTime.fromMillisecondsSinceEpoch(m['created_at'] as int),
      items: itemMaps.map((e) => OpenOrderItem.fromDb(e)).toList(),
    );
  }

  Future<void> createOpenOrder({
    required String orderKey,
    required String orderType,
    int? tableNumber,
    required List<OpenOrderLine> lines,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.insert('open_orders', {
        'order_key': orderKey,
        'order_type': orderType,
        'table_number': tableNumber,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      });
      for (final line in lines) {
        await txn.insert('open_order_items', {
          'order_key': orderKey,
          'product_id': line.productId,
          'product_name': line.productName,
          'price': line.price,
          'hpp': line.hpp,
          'qty': line.qty,
        });
      }
    });
  }

  /// Merge: kalau product_id sama sudah ada, jumlahkan qty.
  Future<void> appendToOpenOrder({
    required String orderKey,
    required List<OpenOrderLine> lines,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      for (final line in lines) {
        if (line.productId != null) {
          final existing = await txn.query('open_order_items',
              where: 'order_key = ? AND product_id = ?',
              whereArgs: [orderKey, line.productId],
              limit: 1);
          if (existing.isNotEmpty) {
            final cur = existing.first;
            final newQty = (cur['qty'] as int) + line.qty;
            await txn.update('open_order_items', {'qty': newQty},
                where: 'id = ?', whereArgs: [cur['id']]);
            continue;
          }
        }
        await txn.insert('open_order_items', {
          'order_key': orderKey,
          'product_id': line.productId,
          'product_name': line.productName,
          'price': line.price,
          'hpp': line.hpp,
          'qty': line.qty,
        });
      }
    });
  }

  Future<void> updateOpenOrderItemQty(int itemId, int qty) async {
    final db = await database;
    if (qty <= 0) {
      await db.delete('open_order_items', where: 'id = ?', whereArgs: [itemId]);
    } else {
      await db.update('open_order_items', {'qty': qty},
          where: 'id = ?', whereArgs: [itemId]);
    }
  }

  Future<void> deleteOpenOrder(String orderKey) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('open_order_items',
          where: 'order_key = ?', whereArgs: [orderKey]);
      await txn
          .delete('open_orders', where: 'order_key = ?', whereArgs: [orderKey]);
    });
  }

  Future<String> nextTakeAwayKey() async {
    final db = await database;
    final fromOpen = await db.rawQuery(
        "SELECT MAX(CAST(SUBSTR(order_key, 4) AS INTEGER)) AS m FROM open_orders WHERE order_type = 'take_away'");
    final fromTx = await db.rawQuery(
        "SELECT MAX(CAST(SUBSTR(table_number, 4) AS INTEGER)) AS m FROM transactions WHERE order_type = 'take_away' AND table_number LIKE 'TA-%'");
    final m1 = (fromOpen.first['m'] as num?)?.toInt() ?? 0;
    final m2 = (fromTx.first['m'] as num?)?.toInt() ?? 0;
    final next = (m1 > m2 ? m1 : m2) + 1;
    return 'TA-${next.toString().padLeft(3, '0')}';
  }
}