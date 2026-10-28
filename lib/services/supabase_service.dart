import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/open_order.dart';
import '../models/product.dart';
import '../models/category.dart';
import '../models/transaction.dart';
import '../models/auth_cache.dart';
import '../core/local_db.dart';
import 'sync_runner.dart';
import 'sync_status_service.dart';

enum LoginMode { online, offline }

class SupabaseService {
  SupabaseService._();
  static final SupabaseService _instance = SupabaseService._();
  factory SupabaseService() => _instance;

  SupabaseClient get _client => Supabase.instance.client;
  final LocalDb _localDb = LocalDb.instance;
  static bool _isSyncing = false;
  static final Random _rng = Random();

  static const String _kOfflineEmailKey = 'offline_session_email';
  String? _cachedOfflineEmail;

  Future<void> initSession() async {
    final prefs = await SharedPreferences.getInstance();
    _cachedOfflineEmail = prefs.getString(_kOfflineEmailKey);
    if (_client.auth.currentSession != null && _cachedOfflineEmail != null) {
      _cachedOfflineEmail = null;
      await prefs.remove(_kOfflineEmailKey);
    }
  }

  // ---- Auth ----

  Future<LoginMode> login(String email, String password) async {
    try {
      await _client.auth.signInWithPassword(email: email, password: password);
      await _saveAuthCache(email, password);
      await _setOfflineSession(null);
      return LoginMode.online;
    } catch (onlineErr) {
      final cache = await _localDb.getAuthCache(email);
      if (cache == null) {
        if (onlineErr is AuthException) rethrow;
        throw AuthException(
            'Login gagal. Login pertama kali memerlukan internet.');
      }
      if (!_hashMatches(password, cache.salt, cache.passwordHash)) {
        throw AuthException('Email atau password salah.');
      }
      if (onlineErr is AuthException) {
        throw AuthException(
            'Password Anda telah berubah di server. Login online untuk memperbarui.');
      }
      await _setOfflineSession(email);
      return LoginMode.offline;
    }
  }

  Future<void> logout() async {
    await _setOfflineSession(null);
    SyncStatusService.instance.reset();
    try {
      await _client.auth.signOut();
    } catch (e) {
      debugPrint('Logout global failed (likely offline): $e');
      try {
        await _client.auth.signOut(scope: SignOutScope.local);
      } catch (e2) {
        debugPrint('Local signout also failed: $e2');
      }
    }
  }

  bool get isLoggedIn =>
      _client.auth.currentSession != null || _cachedOfflineEmail != null;

  bool get isOfflineSession =>
      _client.auth.currentSession == null && _cachedOfflineEmail != null;

  Future<void> _setOfflineSession(String? email) async {
    final prefs = await SharedPreferences.getInstance();
    _cachedOfflineEmail = email;
    if (email == null) {
      await prefs.remove(_kOfflineEmailKey);
    } else {
      await prefs.setString(_kOfflineEmailKey, email);
    }
  }

  Future<void> _saveAuthCache(String email, String password) async {
    final salt = _generateSalt();
    final hash = _hashPassword(password, salt);
    await _localDb.upsertAuthCache(AuthCacheEntry(
      email: email,
      passwordHash: hash,
      salt: salt,
      lastOnlineLoginMs: DateTime.now().millisecondsSinceEpoch,
    ));
  }

  String _generateSalt() {
    final rng = Random.secure();
    return base64Encode(List.generate(16, (_) => rng.nextInt(256)));
  }

  String _hashPassword(String password, String salt) {
    final initial = utf8.encode('$salt$password$salt');
    var digest = sha256.convert(initial);
    for (var i = 0; i < 10000; i++) {
      digest = sha256.convert([...digest.bytes, ...utf8.encode(salt)]);
    }
    return digest.toString();
  }

  bool _hashMatches(String password, String salt, String expectedHash) {
    return _hashPassword(password, salt) == expectedHash;
  }

  // ---- Local read ----

  Future<List<Product>> getLocalProducts() => _localDb.getProducts();
  Future<List<Category>> getLocalCategories() => _localDb.getCategories();

  // ---- Sync ----

  Future<void> syncData() async {
    if (_client.auth.currentSession == null) {
      await SyncStatusService.instance.refreshPendingCount();
      return;
    }

    if (_isSyncing) return;)
    _isSyncing = true;
    SyncStatusService.instance.markSyncing();

    try {
      final failures = await SyncRunner(
        client: _client,
        localDb: _localDb,
        rng: _rng,
      ).run();

      if (failures > 0) {
        SyncStatusService.instance.markFailed(
            'Sinkronisasi gagal ($failures operasi). Akan dicoba lagi otomatis.');
      } else {
        await SyncStatusService.instance.markSynced();
      }
    } catch (e) {
      debugPrint('syncData unexpected error: $e');
      SyncStatusService.instance
          .markFailed('Sinkronisasi gagal: ${e.toString()}');
    } finally {
      _isSyncing = false;
    }
  }

  // ---- CRUD ----

  Future<void> createProduct({
    required String name,
    required int price,
    required int hpp,
    int? categoryId,
    String? localImagePath,
  }) async {
    final tempId = -DateTime.now().millisecondsSinceEpoch;
    await _localDb.upsertProduct(Product(
      id: tempId,
      name: name,
      price: price,
      hpp: hpp,
      categoryId: categoryId,
      localImagePath: localImagePath,
      isSynced: false,
    ));
    await SyncStatusService.instance.refreshPendingCount();
  }

  Future<void> updateProduct({
    required int id,
    required String name,
    required int price,
    required int hpp,
    int? categoryId,
    String? localImagePath,
    String? existingImageUrl,
  }) async {
    await _localDb.upsertProduct(Product(
      id: id,
      name: name,
      price: price,
      hpp: hpp,
      categoryId: categoryId,
      imageUrl: existingImageUrl,
      localImagePath: localImagePath,
      isSynced: false,
    ));
    await SyncStatusService.instance.refreshPendingCount();
  }

  Future<void> deleteProduct(int id) async {
    await _localDb.markProductDeleted(id);
    await SyncStatusService.instance.refreshPendingCount();
  }

  Future<void> createCategory(String name) async {
    final tempId = -DateTime.now().millisecondsSinceEpoch;
    await _localDb
        .upsertCategory(Category(id: tempId, name: name, isSynced: false));
    await SyncStatusService.instance.refreshPendingCount();
  }

  Future<void> updateCategory({required int id, required String name}) async {
    await _localDb
        .upsertCategory(Category(id: id, name: name, isSynced: false));
    await SyncStatusService.instance.refreshPendingCount();
  }

  Future<void> deleteCategory(int id) async {
    await _localDb.markCategoryDeleted(id);
    await SyncStatusService.instance.refreshPendingCount();
  }

  Future<void> saveTransaction({
    required List<TransactionLine> lines,
    required int total,
  }) async {
    final now = DateTime.now();
    final transactionId = -now.toUtc().microsecondsSinceEpoch;
    await _localDb.insertTransaction(
      transactionId: transactionId,
      total: total,
      createdAt: now,
      lines: lines,
    );
    await SyncStatusService.instance.refreshPendingCount();
  }
  
  Future<void> payOpenOrder({
  required String orderKey,
  required int cashReceived,
  required int changeAmount,
}) async {
  final order = await _localDb.getOpenOrder(orderKey);
  if (order == null) throw Exception('Pesanan tidak ditemukan');

  final now = DateTime.now();
  final transactionId = -now.toUtc().microsecondsSinceEpoch;
  final lines = order.items
      .map((e) => TransactionLine(
            productId: e.productId,
            productName: e.productName,
            price: e.price,
            hpp: e.hpp,
            qty: e.qty,
          ))
      .toList();

  await _localDb.insertTransaction(
    transactionId: transactionId,
    total: order.total,
    createdAt: now,
    lines: lines,
    cashReceived: cashReceived,
    changeAmount: changeAmount,
    tableNumber: order.orderKey,
    orderType: order.orderType,
  );
  await _localDb.deleteOpenOrder(orderKey);
  await SyncStatusService.instance.refreshPendingCount();
}

  Future<List<Transaction>> getLocalTransactions({int limit = 100}) async {
    return _localDb.getTransactions(limit: limit);
  }

  Future<Map<String, int>> getTodaySummary() async {
    return _localDb.getTodaySummary();
  }
}