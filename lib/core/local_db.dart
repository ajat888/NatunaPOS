import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/product.dart';

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
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // Tabel untuk menyimpan produk secara offline
    await db.execute('''
      CREATE TABLE products (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        price INTEGER NOT NULL,
        is_synced INTEGER DEFAULT 0
      )
    ''');
  }

  // Fungsi untuk menyimpan produk ke lokal
  Future<void> saveProducts(List<Product> products) async {
    final db = await database;
    final batch = db.batch();

    for (var product in products) {
      batch.insert(
        'products',
        {
          'id': product.id,
          'name': product.name,
          'price': product.price,
          'is_synced': 1, // 1 berarti data ini berasal dari server (sudah sinkron)
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit();
  }

  // Fungsi untuk mengambil produk dari lokal
  Future<List<Product>> getProducts() async {
    final db = await database;
    final maps = await db.query('products');

    return maps.map((map) => Product.fromDb(map)).toList();
  }
}