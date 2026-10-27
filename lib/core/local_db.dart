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
    // Membuat tabel produk
    await db.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        price INTEGER NOT NULL
      )
    ''');
  }

  // Fungsi untuk menyimpan data dari Supabase ke HP
  Future<void> saveProducts(List<Product> products) async {
    final db = await database;
    final batch = db.batch();

    for (var product in products) {
      batch.insert(
        'products',
        product.toDb(),
        conflictAlgorithm: ConflictAlgorithm.replace, // Timpa jika ID sama
      );
    }
    await batch.commit();
  }

  // Fungsi untuk mengambil data dari HP saat offline
  Future<List<Product>> getProducts() async {
    final db = await database;
    final maps = await db.query('products');

    return maps.map((map) => Product.fromDb(map)).toList();
  }
}