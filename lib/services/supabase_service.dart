// lib/services/supabase_service.dart
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/product.dart';
import '../models/category.dart';
import '../models/transaction.dart';
import '../models/auth_cache.dart';
import '../core/local_db.dart';

/// Hasil login — memberi tahu UI apakah sesi terhubung ke server (online)
/// atau hasil verifikasi lokal (offline).
enum LoginMode { online, offline }

class SupabaseService {
  SupabaseService._();
  static final SupabaseService _instance = SupabaseService._();
  factory SupabaseService() => _instance;

  SupabaseClient get _client => Supabase.instance.client;
  final LocalDb _localDb = LocalDb.instance;
  static bool _isSyncing = false;
  static final Random _rng = Random();

  // ---- Offline session state ----
  static const String _kOfflineEmailKey = 'offline_session_email';
  String? _cachedOfflineEmail;

  /// Panggil SEKALI di `main()` sebelum `runApp()`. Memuat flag offline
  /// session dari SharedPreferences & membersihkan jika sudah stale
  /// (Supabase session valid).
  Future<void> initSession() async {
    final prefs = await SharedPreferences.getInstance();
    _cachedOfflineEmail = prefs.getString(_kOfflineEmailKey);
    if (_client.auth.currentSession != null && _cachedOfflineEmail != null) {
      // Ada sesi online valid — flag offline basi.
      _cachedOfflineEmail = null;
      await prefs.remove(_kOfflineEmailKey);
    }
  }

  // ---- Auth ----

  /// Login: coba online, fallback ke cache lokal jika network error.
  Future<LoginMode> login(String email, String password) async {
    try {
      await _client.auth.signInWithPassword(email: email, password: password);
      // Sukses online → simpan cache & clear offline flag.
      await _saveAuthCache(email, password);
      await _setOfflineSession(null);
      return LoginMode.online;
    } catch (onlineErr) {
      // Cek cache lokal
      final cache = await _localDb.getAuthCache(email);
      if (cache == null) {
        // Belum pernah login online di device ini → tidak bisa offline
        if (onlineErr is AuthException) rethrow;
        throw AuthException(
            'Login gagal. Login pertama kali memerlukan internet.');
      }
      if (!_hashMatches(password, cache.salt, cache.passwordHash)) {
        throw AuthException('Email atau password salah.');
      }
      // Cache cocok. Tapi jika server reachable & menolak (is AuthException),
      // berarti password sudah berubah di server → jangan izinkan offline.
      if (onlineErr is AuthException) {
        throw AuthException(
            'Password Anda telah berubah di server. Login online untuk memperbarui.');
      }
      // Network error + cache cocok → masuk offline mode.
      await _setOfflineSession(email);
      return LoginMode.offline;
    }
  }

  /// Offline-safe logout. Clear offline flag + hapus sesi Supabase.
  Future<void> logout() async {
    await _setOfflineSession(null);
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

  // ---- Auth cache helpers ----

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
    // SYNC HANYA JALAN DENGAN SESI SUPABASE VALID.
    // Di offline mode, lewati — antrian akan di-push saat user login online.
    if (_client.auth.currentSession == null) return;

    if (_isSyncing) return;
    _isSyncing = true;

    try {
      // STEP 1: Flush deleted categories
      final deletedCategories = await _localDb.getDeletedCategories();
      for (final c in deletedCategories) {
        try {
          if (c.id > 0) {
            await _client.from('categories').delete().eq('id', c.id);
          }
          await _localDb.deleteCategory(c.id);
        } catch (e) {
          debugPrint('Sync delete category ${c.id} failed: $e');
        }
      }

      // STEP 2: Flush deleted products
      final deletedProducts = await _localDb.getDeletedProducts();
      for (final p in deletedProducts) {
        try {
          if (p.id > 0) {
            await _client.from('products').delete().eq('id', p.id);
          }
          await _localDb.deleteProduct(p.id);
        } catch (e) {
          debugPrint('Sync delete product ${p.id} failed: $e');
        }
      }

      // STEP 3: Push unsynced categories
      final Map<int, int> categoryIdMap = {};
      final unsyncedCategories = await _localDb.getUnsyncedCategories();
      for (final c in unsyncedCategories) {
        try {
          if (c.id < 0) {
            final response = await _client
                .from('categories')
                .insert({'name': c.name})
                .select()
                .single();
            final newId = response['id'] as int;
            categoryIdMap[c.id] = newId;
            await _localDb.deleteCategory(c.id);
            await _localDb.upsertCategory(Category.fromJson(response));
          } else {
            await _client
                .from('categories')
                .update({'name': c.name}).eq('id', c.id);
            await _localDb.upsertCategory(c.copyWith(isSynced: true));
          }
        } catch (e) {
          debugPrint('Sync category ${c.id} failed: $e');
        }
      }

      // STEP 3.5: Remap product.category_id temp ids
      for (final entry in categoryIdMap.entries) {
        try {
          await _localDb.remapProductCategory(entry.key, entry.value);
        } catch (e) {
          debugPrint('Remap category ${entry.key} -> ${entry.value} failed: $e');
        }
      }

      // STEP 4: Push unsynced products
      final unsyncedProducts = await _localDb.getUnsyncedProducts();
      for (final p in unsyncedProducts) {
        try {
          String? finalImageUrl = p.imageUrl;
          String? remainingLocalImagePath = p.localImagePath;

          if (p.localImagePath != null && File(p.localImagePath!).existsSync()) {
            final fileName =
                'product_${DateTime.now().microsecondsSinceEpoch}_${_rng.nextInt(999999)}.jpg';
            await _client
                .storage
                .from('product_images')
                .upload(fileName, File(p.localImagePath!));
            finalImageUrl =
                _client.storage.from('product_images').getPublicUrl(fileName);
            try {
              await File(p.localImagePath!).delete();
            } catch (e) {
              debugPrint('Failed to remove local image: $e');
            }
            remainingLocalImagePath = null;
          }

          int? finalCategoryId = p.categoryId;
          if (finalCategoryId != null &&
              categoryIdMap.containsKey(finalCategoryId)) {
            finalCategoryId = categoryIdMap[finalCategoryId];
          }

          if (p.id < 0) {
            final response = await _client
                .from('products')
                .insert({
                  'name': p.name,
                  'price': p.price,
                  'hpp': p.hpp,
                  'category_id': finalCategoryId,
                  'image_url': finalImageUrl,
                })
                .select()
                .single();
            await _localDb.deleteProduct(p.id);
            await _localDb.upsertProduct(Product.fromJson(response));
          } else {
            await _client
                .from('products')
                .update({
                  'name': p.name,
                  'price': p.price,
                  'hpp': p.hpp,
                  'category_id': finalCategoryId,
                  'image_url': finalImageUrl,
                })
                .eq('id', p.id);
            await _localDb.upsertProduct(Product(
              id: p.id,
              name: p.name,
              price: p.price,
              hpp: p.hpp,
              categoryId: finalCategoryId,
              imageUrl: finalImageUrl,
              localImagePath: remainingLocalImagePath,
              isSynced: true,
            ));
          }
        } catch (e) {
          debugPrint('Sync product ${p.id} failed: $e');
        }
      }

      // STEP 5: Pull server categories
      try {
        final allCategories = <Category>[];
        int offset = 0;
        const pageSize = 1000;
        while (true) {
          final response = await _client
              .from('categories')
              .select()
              .order('id', ascending: true)
              .range(offset, offset + pageSize - 1);
          final list =
              (response as List).map((json) => Category.fromJson(json)).toList();
          allCategories.addAll(list);
          if (list.length < pageSize) break;
          offset += pageSize;
        }
        await _localDb.replaceAllCategories(allCategories);
      } catch (e) {
        debugPrint('Pull categories failed: $e');
      }

      // STEP 6: Pull server products
      try {
        final allProducts = <Product>[];
        int offset = 0;
        const pageSize = 1000;
        while (true) {
          final response = await _client
              .from('products')
              .select()
              .order('id', ascending: true)
              .range(offset, offset + pageSize - 1);
          final list =
              (response as List).map((json) => Product.fromJson(json)).toList();
          allProducts.addAll(list);
          if (list.length < pageSize) break;
          offset += pageSize;
        }
        await _localDb.replaceAllProducts(allProducts);
      } catch (e) {
        debugPrint('Pull products failed: $e');
      }

      // STEP 7: Push unsynced transactions
      final unsyncedTransactions = await _localDb.getUnsyncedTransactions();
      for (final tx in unsyncedTransactions) {
        try {
          if (tx.id < 0) {
            final txResponse = await _client
                .from('transactions')
                .insert({
                  'total': tx.total,
                  'created_at_local': tx.createdAt.millisecondsSinceEpoch,
                })
                .select()
                .single();
            final serverTxId = txResponse['id'] as int;

            try {
              for (final item in tx.items) {
                final pushProductId =
                    (item.productId != null && item.productId! > 0)
                        ? item.productId
                        : null;
                await _client.from('transaction_items').insert({
                  'transaction_id': serverTxId,
                  'product_id': pushProductId,
                  'product_name': item.productName,
                  'price': item.price,
                  'hpp': item.hpp,
                  'qty': item.qty,
                });
              }
            } catch (e) {
              try {
                await _client
                    .from('transactions')
                    .delete()
                    .eq('id', serverTxId);
              } catch (rollbackErr) {
                debugPrint('Rollback tx $serverTxId failed: $rollbackErr');
              }
              rethrow;
            }

            await _localDb.replaceTransactionId(
              oldId: tx.id,
              newId: serverTxId,
            );
          }
        } catch (e) {
          debugPrint('Sync transaction ${tx.id} failed: $e');
        }
      }

      // STEP 8: Pull transactions from server
      //
      // Iterasi paginated. Untuk setiap tx yang belum ada lokal, insert induk
      // + items (items pakai AUTOINCREMENT lokal → tidak bentrok dengan
      // id server yang biasanya besar). Idempotent: pada sync berikutnya,
      // existence check akan skip karena id sudah ada.
      try {
        int offset = 0;
        const pageSize = 500;
        while (true) {
          final response = await _client
              .from('transactions')
              .select(
                  'id, total, created_at_local, transaction_items(product_id, product_name, price, hpp, qty)')
              .order('id', ascending: true)
              .range(offset, offset + pageSize - 1);

          final list = response as List;
          if (list.isEmpty) break;

          final ids = list
              .map((e) => ((e as Map)['id'] as num).toInt())
              .toList();
          final existing = await _localDb.existingTransactionIds(ids);

          for (final raw in list) {
            final m = raw as Map<String, dynamic>;
            final id = (m['id'] as num).toInt();
            if (existing.contains(id)) continue;

            final rawItems =
                (m['transaction_items'] as List?) ?? const <dynamic>[];
            final items = rawItems.map((i) {
              final im = i as Map<String, dynamic>;
              return TransactionLine(
                productId: (im['product_id'] as num?)?.toInt(),
                productName: im['product_name'] as String? ?? '',
                price: (im['price'] as num?)?.toInt() ?? 0,
                hpp: (im['hpp'] as num?)?.toInt() ?? 0,
                qty: (im['qty'] as num?)?.toInt() ?? 0,
              );
            }).toList();

            await _localDb.insertPulledTransaction(
              id: id,
              total: (m['total'] as num?)?.toInt() ?? 0,
              createdAtLocalMs: (m['created_at_local'] as num?)?.toInt() ?? 0,
              items: items,
            );
          }

          if (list.length < pageSize) break;
          offset += pageSize;
        }
      } catch (e) {
        debugPrint('Pull transactions failed: $e');
      }
    } finally {
      _isSyncing = false;
    }
  }

  // ---- Product / category CRUD (tidak berubah) ----

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
  }

  Future<void> deleteProduct(int id) async {
    await _localDb.markProductDeleted(id);
  }

  Future<void> createCategory(String name) async {
    final tempId = -DateTime.now().millisecondsSinceEpoch;
    await _localDb
        .upsertCategory(Category(id: tempId, name: name, isSynced: false));
  }

  Future<void> updateCategory({required int id, required String name}) async {
    await _localDb.upsertCategory(Category(id: id, name: name, isSynced: false));
  }

  Future<void> deleteCategory(int id) async {
    await _localDb.markCategoryDeleted(id);
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
  }

  Future<List<Transaction>> getLocalTransactions({int limit = 100}) async {
    return _localDb.getTransactions(limit: limit);
  }

  Future<Map<String, int>> getTodaySummary() async {
    return _localDb.getTodaySummary();
  }
}