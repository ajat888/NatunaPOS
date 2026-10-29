// lib/core/local_db/local_db_transactions.dart
import 'package:sqflite/sqflite.dart' hide Transaction;
import '../../models/transaction.dart';

mixin LocalDbTransactions {
  Future<Database> get database;

  static Future<void> createTableTransactions(Database db) async {
    await db.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY,
        total INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        is_synced INTEGER DEFAULT 0,
        is_deleted INTEGER DEFAULT 0,
        cash_received INTEGER DEFAULT 0,
        change_amount INTEGER DEFAULT 0,
        table_number TEXT,
        order_type TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE transaction_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        transaction_id INTEGER NOT NULL,
        product_id INTEGER,
        product_name TEXT NOT NULL,
        price INTEGER NOT NULL,
        hpp INTEGER NOT NULL,
        qty INTEGER NOT NULL
      )
    ''');
    await db.execute(
        'CREATE INDEX idx_tx_items_tx ON transaction_items(transaction_id)');
    await db.execute('CREATE INDEX idx_tx_created ON transactions(created_at)');
  }

  static Future<void> createTableTransactionsLegacy(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS transactions (
        id INTEGER PRIMARY KEY,
        total INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        is_synced INTEGER DEFAULT 0,
        is_deleted INTEGER DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS transaction_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        transaction_id INTEGER NOT NULL,
        product_id INTEGER,
        product_name TEXT NOT NULL,
        price INTEGER NOT NULL,
        hpp INTEGER NOT NULL,
        qty INTEGER NOT NULL
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_tx_items_tx ON transaction_items(transaction_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_tx_created ON transactions(created_at)');
  }

  static Future<void> upgradeTransactionsV8(Database db) async {
    await db.execute(
        'ALTER TABLE transactions ADD COLUMN cash_received INTEGER DEFAULT 0');
    await db.execute(
        'ALTER TABLE transactions ADD COLUMN change_amount INTEGER DEFAULT 0');
    await db.execute('ALTER TABLE transactions ADD COLUMN table_number TEXT');
    await db.execute('ALTER TABLE transactions ADD COLUMN order_type TEXT');
  }

  Future<void> insertTransaction({
    required int transactionId,
    required int total,
    required DateTime createdAt,
    required List<TransactionLine> lines,
    int cashReceived = 0,
    int changeAmount = 0,
    String? tableNumber,
    String? orderType,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.insert('transactions', {
        'id': transactionId,
        'total': total,
        'created_at': createdAt.toUtc().millisecondsSinceEpoch,
        'is_synced': 0,
        'is_deleted': 0,
        'cash_received': cashReceived,
        'change_amount': changeAmount,
        'table_number': tableNumber,
        'order_type': orderType,
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
    });
  }

  Future<List<Transaction>> getTransactions({int limit = 100}) async {
    final db = await database;
    final txMaps = await db.query('transactions',
        where: 'is_deleted = 0', orderBy: 'created_at DESC', limit: limit);
    if (txMaps.isEmpty) return [];
    final txIds = txMaps.map((m) => m['id'] as int).toList();
    final placeholders = List.filled(txIds.length, '?').join(',');
    final itemMaps = await db.query('transaction_items',
        where: 'transaction_id IN ($placeholders)', whereArgs: txIds);
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

  Future<Map<String, int>> getTodaySummary() async {
    final db = await database;
    final now = DateTime.now();
    final startLocal = DateTime(now.year, now.month, now.day);
    final endLocal = DateTime(now.year, now.month, now.day + 1);
    final result = await db.rawQuery('''
      SELECT COUNT(*) AS c, COALESCE(SUM(total), 0) AS t
      FROM transactions
      WHERE is_deleted = 0 AND created_at >= ? AND created_at < ?
    ''', [
      startLocal.millisecondsSinceEpoch,
      endLocal.millisecondsSinceEpoch
    ]);
    final row = result.first;
    return {
      'count': (row['c'] as num?)?.toInt() ?? 0,
      'total': (row['t'] as num?)?.toInt() ?? 0,
    };
  }

  Future<List<Transaction>> getUnsyncedTransactions() async {
    final db = await database;
    final txMaps = await db.query('transactions',
        where: 'is_synced = 0 AND is_deleted = 0', orderBy: 'created_at ASC');
    if (txMaps.isEmpty) return [];
    final txIds = txMaps.map((m) => m['id'] as int).toList();
    final placeholders = List.filled(txIds.length, '?').join(',');
    final itemMaps = await db.query('transaction_items',
        where: 'transaction_id IN ($placeholders)', whereArgs: txIds);
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

  Future<void> replaceTransactionId({
    required int oldId,
    required int newId,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.update(
        'transactions',
        {'id': newId, 'is_synced': 1},
        where: 'id = ?',
        whereArgs: [oldId],
      );
      await txn.update(
        'transaction_items',
        {'transaction_id': newId},
        where: 'transaction_id = ?',
        whereArgs: [oldId],
      );
    });
  }

  Future<Set<int>> existingTransactionIds(List<int> ids) async {
    if (ids.isEmpty) return {};
    final db = await database;
    final placeholders = List.filled(ids.length, '?').join(',');
    final maps = await db.query(
      'transactions',
      columns: ['id'],
      where: 'id IN ($placeholders)',
      whereArgs: ids,
    );
    return maps.map((m) => m['id'] as int).toSet();
  }

  /// Isu A: setelah produk lokal (id negatif) berhasil di-push ke server dan
  /// mendapat ID positif, semua referensi di transaction_items harus di-remap
  /// agar transaksi yang belum tersinkron tetap punya link ke produk server
  /// saat di-push pada STEP 7.
  Future<void> remapTransactionItemProductId(int oldId, int newId) async {
    final db = await database;
    await db.update(
      'transaction_items',
      {'product_id': newId},
      where: 'product_id = ?',
      whereArgs: [oldId],
    );
  }

  Future<void> insertPulledTransaction({
    required int id,
    required int total,
    required int createdAtLocalMs,
    required List<TransactionLine> items,
    int cashReceived = 0,
    int changeAmount = 0,
    String? tableNumber,
    String? orderType,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.insert(
        'transactions',
        {
          'id': id,
          'total': total,
          'created_at': createdAtLocalMs,
          'is_synced': 1,
          'is_deleted': 0,
          'cash_received': cashReceived,
          'change_amount': changeAmount,
          'table_number': tableNumber,
          'order_type': orderType,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      for (final line in items) {
        await txn.insert('transaction_items', {
          'transaction_id': id,
          'product_id': line.productId,
          'product_name': line.productName,
          'price': line.price,
          'hpp': line.hpp,
          'qty': line.qty,
        });
      }
    });
  }
}