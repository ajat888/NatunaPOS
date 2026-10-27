import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/product.dart';
import '../models/category.dart';

class LocalDb {
  static final LocalDb instance = LocalDb._init();
  static Database? _database;

  LocalDb._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('natunapos.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(
      path,
      version: 5,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('CREATE TABLE categories (id INTEGER PRIMARY KEY, name TEXT NOT NULL, is_active INTEGER DEFAULT 1)');
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
        is_active INTEGER DEFAULT 1
      )
    ''');
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('CREATE TABLE IF NOT EXISTS categories (id INTEGER PRIMARY KEY, name TEXT NOT NULL)');
      await db.execute('ALTER TABLE products ADD COLUMN category_id INTEGER');
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE products ADD COLUMN hpp INTEGER DEFAULT 0');
      await db.execute('ALTER TABLE products ADD COLUMN image_url TEXT');
    }
    if (oldVersion < 4) {
      await db.execute('ALTER TABLE products ADD COLUMN local_image_path TEXT');
      await db.execute('ALTER TABLE products ADD COLUMN is_synced INTEGER DEFAULT 1');
    }
    if (oldVersion < 5) {
      await db.execute('ALTER TABLE categories ADD COLUMN is_active INTEGER DEFAULT 1');
      await db.execute('ALTER TABLE products ADD COLUMN is_active INTEGER DEFAULT 1');
    }
  }

  // === PRODUCTS ===
  Future<void> replaceAllProducts(List<Product> serverProducts) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('products', where: 'is_synced = 1');
      final batch = txn.batch();
      for (final p in serverProducts) {
        batch.insert('products', p.toDb(), conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    });
  }

  Future<List<Product>> getProducts() async {
    final db = await database;
    final maps = await db.query('products', orderBy: 'id ASC');
    return maps.map((m) => Product.fromDb(m)).toList();
  }

  Future<List<Product>> getUnsyncedProducts() async {
    final db = await database;
    final maps = await db.query('products', where: 'is_synced = 0');
    return maps.map((m) => Product.fromDb(m)).toList();
  }

  Future<void> upsertProduct(Product product) async {
    final db = await database;
    await db.insert('products', product.toDb(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // Ubah fungsi delete menjadi Soft Delete (Update is_active = 0)
  Future<void> softDeleteProduct(int id) async {
    final db = await database;
    await db.update(
      'products',
      {'is_active': 0, 'is_synced': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> hardDeleteProduct(int id) async {
    final db = await database;
    await db.delete('products', where: 'id = ?', whereArgs: [id]);
  }

  // === CATEGORIES ===
  Future<void> replaceAllCategories(List<Category> categories) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('categories', where: 'id > 0');
      final batch = txn.batch();
      for (final c in categories) {
        batch.insert('categories', c.toDb(), conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    });
  }

  Future<List<Category>> getCategories() async {
    final db = await database;
    final maps = await db.query('categories', orderBy: 'id ASC');
    return maps.map((m) => Category.fromDb(m)).toList();
  }

  Future<void> upsertCategory(Category category) async {
    final db = await database;
    await db.insert('categories', category.toDb(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> softDeleteCategory(int id) async {
    final db = await database;
    await db.transaction((txn) async {
      // Nonaktifkan kategori
      await txn.update(
        'categories',
        {'is_active': 0},
        where: 'id = ?',
        whereArgs: [id],
      );
      // Nonaktifkan semua produk di kategori ini juga (opsional, tapi logis)
      await txn.update(
        'products',
        {'is_active': 0, 'is_synced': 0},
        where: 'category_id = ?',
        whereArgs: [id],
      );
    });
  }
}