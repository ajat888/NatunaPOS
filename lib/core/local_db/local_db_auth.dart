// lib/core/local_db/local_db_auth.dart
import 'package:sqflite/sqflite.dart';
import '../../models/auth_cache.dart';

mixin LocalDbAuth {
  Future<Database> get database;

  static Future<void> createTableAuthCache(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS auth_cache (
        email TEXT PRIMARY KEY,
        password_hash TEXT NOT NULL,
        salt TEXT NOT NULL,
        last_online_login_ms INTEGER NOT NULL
      )
    ''');
  }

  Future<void> upsertAuthCache(AuthCacheEntry entry) async {
    final db = await database;
    await db.insert('auth_cache', entry.toDb(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<AuthCacheEntry?> getAuthCache(String email) async {
    final db = await database;
    final maps = await db
        .query('auth_cache', where: 'email = ?', whereArgs: [email], limit: 1);
    if (maps.isEmpty) return null;
    return AuthCacheEntry.fromDb(maps.first);
  }

  Future<void> deleteAuthCache(String email) async {
    final db = await database;
    await db.delete('auth_cache', where: 'email = ?', whereArgs: [email]);
  }
}