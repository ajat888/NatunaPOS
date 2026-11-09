import 'package:flutter/foundation.dart' show debugPrint;
import 'package:sqflite/sqflite.dart' hide Transaction;
import '../../models/transaction.dart';
import '../../services/write_notifier.dart';

mixin LocalDbTransactions {
  Future<Database> get database;

  static Future<void> createTableTransactions(Database db) async {
    await db.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY,
        total INTEGER NOT NULL,
        subtotal INTEGER DEFAULT 0,
        bill_discount INTEGER DEFAULT 0,
        discount_type TEXT DEFAULT 'nominal',
        discount_value INTEGER DEFAULT 0,
        tax_rate REAL DEFAULT 0,
        tax_amount INTEGER DEFAULT 0,
        created_at INTEGER NOT NULL,
        is_synced INTEGER DEFAULT 0,
        is_deleted INTEGER DEFAULT 0,
        cash_received INTEGER DEFAULT 0,
        change_amount INTEGER DEFAULT 0,
        table_number TEXT,
        order_type TEXT,
        parent_order_key TEXT,
        is_voided INTEGER DEFAULT 0,
        void_reason TEXT,
        voided_by TEXT,
        voided_at INTEGER
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
    try {
      await db.execute(
          'ALTER TABLE transactions ADD COLUMN cash_received INTEGER DEFAULT 0');
    } catch (e) {
      debugPrint('transactions.cash_received already exists: $e');
    }
    try {
      await db.execute(
          'ALTER TABLE transactions ADD COLUMN change_amount INTEGER DEFAULT 0');
    } catch (e) {
      debugPrint('transactions.change_amount already exists: $e');
    }
    try {
      await db.execute('ALTER TABLE transactions ADD COLUMN table_number TEXT');
    } catch (e) {
      debugPrint('transactions.table_number already exists: $e');
    }
    try {
      await db.execute('ALTER TABLE transactions ADD COLUMN order_type TEXT');
    } catch (e) {
      debugPrint('transactions.order_type already exists: $e');
    }
  }

  static Future<void> upgradeTransactionsV9(Database db) async {
    try {
      await db.execute(
          'ALTER TABLE transactions ADD COLUMN subtotal INTEGER DEFAULT 0');
    } catch (e) {
      debugPrint('transactions.subtotal already exists: $e');
    }
    try {
      await db.execute(
          'ALTER TABLE transactions ADD COLUMN bill_discount INTEGER DEFAULT 0');
    } catch (e) {
      debugPrint('transactions.bill_discount already exists: $e');
    }
    try {
      await db.execute(
          "ALTER TABLE transactions ADD COLUMN discount_type TEXT DEFAULT 'nominal'");
    } catch (e) {
      debugPrint('transactions.discount_type already exists: $e');
    }
    try {
      await db.execute(
          'ALTER TABLE transactions ADD COLUMN discount_value INTEGER DEFAULT 0');
    } catch (e) {
      debugPrint('transactions.discount_value already exists: $e');
    }
    try {
      await db.execute(
          'ALTER TABLE transactions ADD COLUMN tax_rate REAL DEFAULT 0');
    } catch (e) {
      debugPrint('transactions.tax_rate already exists: $e');
    }
    try {
      await db.execute(
          'ALTER TABLE transactions ADD COLUMN tax_amount INTEGER DEFAULT 0');
    } catch (e) {
      debugPrint('transactions.tax_amount already exists: $e');
    }
  }

  static Future<void> upgradeTransactionsV11(Database db) async {
    try {
      await db.execute(
          'ALTER TABLE transactions ADD COLUMN parent_order_key TEXT');
    } catch (e) {
      debugPrint('transactions.parent_order_key already exists: $e');
    }
  }

  static Future<void> upgradeTransactionsV13(Database db) async {
    try {
      await db.execute(
          'ALTER TABLE transactions ADD COLUMN is_voided INTEGER DEFAULT 0');
    } catch (e) {
      debugPrint('transactions.is_voided already exists: $e');
    }
    try {
      await db.execute(
          'ALTER TABLE transactions ADD COLUMN void_reason TEXT');
    } catch (e) {
      debugPrint('transactions.void_reason already exists: $e');
    }
    try {
      await db.execute('ALTER TABLE transactions ADD COLUMN voided_by TEXT');
    } catch (e) {
      debugPrint('transactions.voided_by already exists: $e');
    }
    try {
      await db.execute(
          'ALTER TABLE transactions ADD COLUMN voided_at INTEGER');
    } catch (e) {
      debugPrint('transactions.voided_at already exists: $e');
    }
  }

  Future<void> insertTransaction({
    required int transactionId,
    required int total,
    int subtotal = 0,
    int billDiscount = 0,
    String discountType = 'nominal',
    int discountValue = 0,
    double taxRate = 0,
    int taxAmount = 0,
    required DateTime createdAt,
    required List<TransactionLine> lines,
    int cashReceived = 0,
    int changeAmount = 0,
    String? tableNumber,
    String? orderType,
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
    });
    if (!skipSync) await WriteNotifier.notify();
  }

  Future<List<Transaction>> getTransactions({
    int limit = 200,
    bool includeVoided = true,
  }) async {
    final db = await database;
    final whereClause =
        includeVoided ? 'is_deleted = 0' : 'is_deleted = 0 AND is_voided = 0';
    final txMaps = await db.query('transactions',
        where: whereClause, orderBy: 'created_at DESC', limit: limit);
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
      WHERE is_deleted = 0 AND is_voided = 0
        AND created_at >= ? AND created_at < ?
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
      where: 'is_synced = 0 AND is_deleted = 0',
      orderBy: 'created_at ASC');
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

  Future<List<Transaction>> getUnsyncedVoidedTransactions() async {
    final db = await database;
    final txMaps = await db.query('transactions',
        where: 'is_voided = 1 AND is_synced = 0 AND is_deleted = 0',
        orderBy: 'created_at ASC');
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

  Future<void> voidTransaction({
    required int id,
    required String reason,
    required String voidedBy,
    bool skipSync = false,
  }) async {
    final db = await database;
    await db.update(
      'transactions',
      {
        'is_voided': 1,
        'void_reason': reason,
        'voided_by': voidedBy,
        'voided_at': DateTime.now().toUtc().millisecondsSinceEpoch,
        'is_synced': 0,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    if (!skipSync) await WriteNotifier.notify();
  }

  Future<void> markTransactionVoidSynced(int id, {bool skipSync = false}) async {
    final db = await database;
    await db.update('transactions', {'is_synced': 1},
        where: 'id = ?', whereArgs: [id]);
    if (!skipSync) await WriteNotifier.notify();
  }

  Future<void> updateVoidedTransactionFromPull({
  required int id,
  required bool isVoided,
  String? voidReason,
  String? voidedBy,
  int? voidedAtMs,
  bool skipSync = false,
}) async {
  if (!isVoided) return;
  final db = await database;
  await db.update(
    'transactions',
    {
      'is_voided': 1,
      'void_reason': voidReason,
      'voided_by': voidedBy,
      'voided_at': voidedAtMs,
      'is_synced': 1,
    },
    where: 'id = ? AND is_voided = 0',
    whereArgs: [id],
  );
  if (!skipSync) await WriteNotifier.notify();
}

  Future<void> replaceTransactionId({
    required int oldId,
    required int newId,
    bool skipSync = false,
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
    if (!skipSync) await WriteNotifier.notify();
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

  Future<void> remapTransactionItemProductId(int oldId, int newId, {bool skipSync = false}) async {
    final db = await database;
    await db.update(
      'transaction_items',
      {'product_id': newId},
      where: 'product_id = ?',
      whereArgs: [oldId],
    );
    if (!skipSync) await WriteNotifier.notify();
  }

  Future<void> insertPulledTransaction({
    required int id,
    required int total,
    required int createdAtLocalMs,
    required List<TransactionLine> items,
    int subtotal = 0,
    int billDiscount = 0,
    String discountType = 'nominal',
    int discountValue = 0,
    double taxRate = 0,
    int taxAmount = 0,
    int cashReceived = 0,
    int changeAmount = 0,
    String? tableNumber,
    String? orderType,
    String? parentOrderKey,
    bool isVoided = false,
    String? voidReason,
    String? voidedBy,
    int? voidedAtMs,
    bool skipSync = false,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      final insertResult = await txn.insert(
        'transactions',
        {
          'id': id,
          'total': total,
          'subtotal': subtotal,
          'bill_discount': billDiscount,
          'discount_type': discountType,
          'discount_value': discountValue,
          'tax_rate': taxRate,
          'tax_amount': taxAmount,
          'created_at': createdAtLocalMs,
          'is_synced': 1,
          'is_deleted': 0,
          'cash_received': cashReceived,
          'change_amount': changeAmount,
          'table_number': tableNumber,
          'order_type': orderType,
          'parent_order_key': parentOrderKey,
          'is_voided': isVoided ? 1 : 0,
          'void_reason': voidReason,
          'voided_by': voidedBy,
          'voided_at': voidedAtMs,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      if (insertResult == 0) return;
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
    if (!skipSync) await WriteNotifier.notify();
  }
}