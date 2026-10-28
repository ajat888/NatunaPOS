// lib/core/local_db.dart
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:sqflite/sqflite.dart' hide Transaction;
import 'package:path/path.dart';
import 'local_db/local_db_products.dart';
import 'local_db/local_db_categories.dart';
import 'local_db/local_db_transactions.dart';
import 'local_db/local_db_open_orders.dart';
import 'local_db/local_db_auth.dart';

class LocalDb with
    LocalDbProducts,
    LocalDbCategories,
    LocalDbTransactions,
    LocalDbOpenOrders,
    LocalDbAuth {
  static final LocalDb instance = LocalDb._init();
  static Future<Database>? _dbFuture;

  LocalDb._init();

  @override
  Future<Database> get database async {
    _dbFuture ??= _initDB('natunapos.db');
    return _dbFuture!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(
      path,
      version: 8,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await LocalDbProducts.createTableProducts(db);
    await LocalDbCategories.createTableCategories(db);
    await LocalDbTransactions.createTableTransactions(db);
    await LocalDbAuth.createTableAuthCache(db);
    await LocalDbOpenOrders.createTableOpenOrders(db);
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await LocalDbCategories.createTableCategoriesLegacy(db);
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
      await LocalDbTransactions.createTableTransactionsLegacy(db);
    }
    if (oldVersion < 7) {
      await LocalDbAuth.createTableAuthCache(db);
    }
    if (oldVersion < 8) {
      await LocalDbTransactions.upgradeTransactionsV8(db);
      await LocalDbOpenOrders.createTableOpenOrders(db);
    }
  }

  Future<int> countPendingSync() async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT
        (SELECT COUNT(*) FROM products      WHERE is_synced = 0)
      + (SELECT COUNT(*) FROM categories    WHERE is_synced = 0)
      + (SELECT COUNT(*) FROM transactions  WHERE is_synced = 0)
      AS total
    ''');
    final v = result.first['total'];
    if (v is int) return v;
    if (v is num) return v.toInt();
    return 0;
  }
}