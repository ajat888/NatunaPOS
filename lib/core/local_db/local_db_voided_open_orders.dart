import 'package:sqflite/sqflite.dart';
import '../../models/voided_open_order.dart';

mixin LocalDbVoidedOpenOrders {
  Future<Database> get database;

  static Future<void> createTableVoidedOpenOrders(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS voided_open_orders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        order_key TEXT NOT NULL,
        order_type TEXT NOT NULL,
        table_number INTEGER,
        subtotal INTEGER NOT NULL,
        item_count INTEGER NOT NULL,
        items_json TEXT NOT NULL,
        void_reason TEXT NOT NULL,
        voided_by TEXT NOT NULL,
        voided_at INTEGER NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_voided_open_orders_at ON voided_open_orders(voided_at DESC)');
  }

  static Future<void> upgradeVoidedOpenOrdersV14(Database db) async {
    await createTableVoidedOpenOrders(db);
  }

  Future<void> archiveVoidedOpenOrder(VoidedOpenOrder voided) async {
    final db = await database;
    await db.insert('voided_open_orders', voided.toDb());
  }

  Future<List<VoidedOpenOrder>> getVoidedOpenOrders({int limit = 200}) async {
    final db = await database;
    final maps = await db.query(
      'voided_open_orders',
      orderBy: 'voided_at DESC',
      limit: limit,
    );
    return maps.map((m) => VoidedOpenOrder.fromDb(m)).toList();
  }

  Future<List<VoidedOpenOrder>> getVoidedOpenOrdersBetween(
      DateTime from, DateTime to) async {
    final db = await database;
    final maps = await db.query(
      'voided_open_orders',
      where: 'voided_at >= ? AND voided_at < ?',
      whereArgs: [
        from.toUtc().millisecondsSinceEpoch,
        to.toUtc().millisecondsSinceEpoch,
      ],
      orderBy: 'voided_at DESC',
    );
    return maps.map((m) => VoidedOpenOrder.fromDb(m)).toList();
  }

  Future<int> countVoidedOpenOrders() async {
    final db = await database;
    final result =
        await db.rawQuery('SELECT COUNT(*) AS c FROM voided_open_orders');
    return (result.first['c'] as num?)?.toInt() ?? 0;
  }
}