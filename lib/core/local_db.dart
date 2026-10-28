// lib/core/local_db.dart
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/product.dart';
import '../models/category.dart';
import '../models/transaction.dart';

class LocalDb {
  static final LocalDb instance = LocalDb._init();
  static Future<Database>? _dbFuture;

  LocalDb._init();

  Future<Database> get database async {
    _dbFuture ??= _initDB('natunapos.db');
    return _dbFuture!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(
      path,
      version: 6,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        is_synced INTEGER DEFAULT 1,
        is_deleted INTEGER DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        price INTEGER NOT NULL,
        hpp INTEGER DEFAULT 0,
        category_id INTEGER,
        image_url TEXT,
        local_image_path TEXT,
        is_synced INTEGER DEFAULT 1,
        is_deleted INTEGER DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY,
        total INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        is_synced INTEGER DEFAULT 0,
        is_deleted INTEGER DEFAULT 0
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
    await db.execute(
        'CREATE INDEX idx_tx_created ON transactions(created_at)');
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
          'CREATE TABLE IF NOT EXISTS categories (id INTEGER PRIMARY KEY, name TEXT NOT NULL)');
      await db.execute('ALTER TABLE products ADD COLUMN category_id INTEGER');
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE products ADD COLUMN hpp INTEGER DEFAULT 0');
      await db.execute('ALTER TABLE products ADD COLUMN image_url TEXT');
    }
    if (oldVersion < 4) {
      await db.execute('ALTER TABLE products ADD COLUMN local_image_path TEXT');
      await db.execute(
          'ALTER TABLE products ADD COLUMN is_synced INTEGER DEFAULT 1');
    }
    if (oldVersion < 5) {
      try {
        await db.execute(
            'ALTER TABLE categories ADD COLUMN is_synced INTEGER DEFAULT 1');
      } catch (e) {
        debugPrint('categories.is_synced already exists: $e');
      }
      try {
        await db.execute(
            'ALTER TABLE categories ADD COLUMN is_deleted INTEGER DEFAULT 0');
      } catch (e) {
        debugPrint('categories.is_deleted already exists: $e');
      }
      try {
        await db.execute(
            'ALTER TABLE products ADD COLUMN is_deleted INTEGER DEFAULT 0');
      } catch (e) {
        debugPrint('products.is_deleted already exists: $e');
      }
    }
    if (oldVersion < 6) {
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
  }

  // ============ PRODUCTS ============

  Future<void> replaceAllProducts(List<Product> serverProducts) async {
    final db = await database;
    await db.transaction((txn) async {
      final unsyncedMaps = await txn.query('products', where: 'is_synced = 0');
      final unsyncedIds = unsyncedMaps.map((m) => m['id'] as int).toSet();

      await txn.delete('products', where: 'is_synced = 1');
      final batch = txn.batch();
      for (final p in serverProducts) {
        if (unsyncedIds.contains(p.id)) continue;
        batch.insert('products', p.toDb(),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    });
  }

  Future<List<Product>> getProducts() async {
    final db = await database;
    final maps =
        await db.query('products', where: 'is_deleted = 0', orderBy: 'id ASC');
    return maps.map((m) => Product.fromDb(m)).toList();
  }

  Future<List<Product>> getUnsyncedProducts() async {
    final db = await database;
    final maps = await db
        .query('products', where: 'is_synced = 0 AND is_deleted = 0');
    return maps.map((m) => Product.fromDb(m)).toList();
  }

  Future<List<Product>> getDeletedProducts() async {
    final db = await database;
    final maps = await db
        .query('products', where: 'is_deleted = 1 AND is_synced = 0');
    return maps.map((m) => Product.fromDb(m)).toList();
  }

  Future<void> upsertProduct(Product product) async {
    final db = await database;
    await db.insert('products', product.toDb(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteProduct(int id) async {
    final db = await database;
    await db.delete('products', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> markProductDeleted(int id) async {
    final db = await database;
    await db.update('products', {'is_deleted': 1, 'is_synced': 0},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<void> remapProductCategory(int oldCategoryId, int newCategoryId) async {
    final db = await database;
    await db.update(
      'products',
      {'category_id': newCategoryId, 'is_synced': 0},
      where: 'category_id = ?',
      whereArgs: [oldCategoryId],
    );
  }

  // ============ CATEGORIES ============

  Future<void> replaceAllCategories(List<Category> categories) async {
    final db = await database;
    await db.transaction((txn) async {
      final unsyncedMaps =
          await txn.query('categories', where: 'is_synced = 0');
      final unsyncedIds = unsyncedMaps.map((m) => m['id'] as int).toSet();

      await txn.delete('categories', where: 'is_synced = 1');
      final batch = txn.batch();
      for (final c in categories) {
        if (unsyncedIds.contains(c.id)) continue;
        batch.insert('categories', c.toDb(),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    });
  }

  Future<List<Category>> getCategories() async {
    final db = await database;
    final maps = await db
        .query('categories', where: 'is_deleted = 0', orderBy: 'id ASC');
    return maps.map((m) => Category.fromDb(m)).toList();
  }

  Future<List<Category>> getUnsyncedCategories() async {
    final db = await database;
    final maps = await db
        .query('categories', where: 'is_synced = 0 AND is_deleted = 0');
    return maps.map((m) => Category.fromDb(m)).toList();
  }

  Future<List<Category>> getDeletedCategories() async {
    final db = await database;
    final maps = await db
        .query('categories', where: 'is_deleted = 1 AND is_synced = 0');
    return maps.map((m) => Category.fromDb(m)).toList();
  }

  Future<void> upsertCategory(Category category) async {
    final db = await database;
    await db.insert('categories', category.toDb(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteCategory(int id) async {
    final db = await database;
    await db.delete('categories', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> markCategoryDeleted(int id) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.update(
        'products',
        {'category_id': null, 'is_synced': 0},
        where: 'category_id = ?',
        whereArgs: [id],
      );
      await txn.update(
        'categories',
        {'is_deleted': 1, 'is_synced': 0},
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }

  // ============ TRANSACTIONS ============

  /// Simpan transaksi baru + items secara atomik.
  /// [transactionId] negatif (unsynced). [createdAt] akan disimpan sebagai
  /// epoch milliseconds UTC (integer) untuk perbandingan numerik yang andal.
  Future<void> insertTransaction({
    required int transactionId,
    required int total,
    required DateTime createdAt,
    required List<TransactionLine> lines,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.insert('transactions', {
        'id': transactionId,
        'total': total,
        'created_at': createdAt.toUtc().millisecondsSinceEpoch,
        'is_synced': 0,
        'is_deleted': 0,
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

  /// Ambil transaksi terbaru (default 100) lengkap dengan items.
  Future<List<Transaction>> getTransactions({int limit = 100}) async {
    final db = await database;
    final txMaps = await db.query(
      'transactions',
      where: 'is_deleted = 0',
      orderBy: 'created_at DESC',
      limit: limit,
    );
    if (txMaps.isEmpty) return [];

    final txIds = txMaps.map((m) => m['id'] as int).toList();
    final placeholders = List.filled(txIds.length, '?').join(',');
    final itemMaps = await db.query(
      'transaction_items',
      where: 'transaction_id IN ($placeholders)',
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

  /// Ringkasan hari ini (local timezone): jumlah transaksi & total penjualan.
  Future<Map<String, int>> getTodaySummary() async {
    final db = await database;
    final now = DateTime.now();
    // Gunakan konstruktor DateTime lokal dengan (day + 1) agar otomatis
    // menangani rollover bulan/tahun dan DST dengan benar.
    final startLocal = DateTime(now.year, now.month, now.day);
    final endLocal = DateTime(now.year, now.month, now.day + 1);
    final startMs = startLocal.millisecondsSinceEpoch;
    final endMs = endLocal.millisecondsSinceEpoch;

    final result = await db.rawQuery('''
      SELECT COUNT(*) AS c, COALESCE(SUM(total), 0) AS t
      FROM transactions
      WHERE is_deleted = 0 AND created_at >= ? AND created_at < ?
    ''', [startMs, endMs]);

    final row = result.first;
    return {
      'count': (row['c'] as num?)?.toInt() ?? 0,
      'total': (row['t'] as num?)?.toInt() ?? 0,
    };
  }
}