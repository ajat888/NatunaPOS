// lib/core/local_db/local_db_products.dart
import 'package:sqflite/sqflite.dart';
import '../../models/product.dart';

mixin LocalDbProducts {
  Future<Database> get database;

  static Future<void> createTableProducts(Database db) async {
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
  }

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

  Future<List<Product>> getInactiveProducts() async {
    final db = await database;
    final maps =
        await db.query('products', where: 'is_deleted = 1', orderBy: 'id ASC');
    return maps.map((m) => Product.fromDb(m)).toList();
  }

  Future<List<Product>> getUnsyncedProducts() async {
    final db = await database;
    final maps =
        await db.query('products', where: 'is_synced = 0 AND is_deleted = 0');
    return maps.map((m) => Product.fromDb(m)).toList();
  }

  Future<List<Product>> getDeletedProducts() async {
    final db = await database;
    final maps =
        await db.query('products', where: 'is_deleted = 1 AND is_synced = 0');
    return maps.map((m) => Product.fromDb(m)).toList();
  }

  Future<bool> isProductNameDuplicate(String name, {int? excludeId}) async {
    final db = await database;
    final whereClause = excludeId != null
        ? 'LOWER(name) = ? AND is_deleted = 0 AND id != ?'
        : 'LOWER(name) = ? AND is_deleted = 0';
    final whereArgsList = excludeId != null
        ? [name.toLowerCase().trim(), excludeId]
        : [name.toLowerCase().trim()];

    final maps = await db.query(
      'products',
      where: whereClause,
      whereArgs: whereArgsList,
      limit: 1,
    );
    return maps.isNotEmpty;
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

  Future<void> restoreProduct(int id) async {
    final db = await database;
    await db.update('products', {'is_deleted': 0, 'is_synced': 0},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<void> markProductSyncedAndDeleted(int id) async {
    final db = await database;
    await db.update('products', {'is_synced': 1},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<void> remapProductCategory(
      int oldCategoryId, int newCategoryId) async {
    final db = await database;
    await db.update(
      'products',
      {'category_id': newCategoryId, 'is_synced': 0},
      where: 'category_id = ?',
      whereArgs: [oldCategoryId],
    );
  }

  Future<void> transactionalReplaceProduct({
    required int oldId,
    required Product newProduct,
    required int newServerId,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.insert('products', newProduct.toDb(),
          conflictAlgorithm: ConflictAlgorithm.replace);
      await txn.update(
        'transaction_items',
        {'product_id': newServerId},
        where: 'product_id = ?',
        whereArgs: [oldId],
      );
      await txn.update(
        'open_order_items',
        {'product_id': newServerId},
        where: 'product_id = ?',
        whereArgs: [oldId],
      );
      await txn.delete('products', where: 'id = ?', whereArgs: [oldId]);
    });
  }
}