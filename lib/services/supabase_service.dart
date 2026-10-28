// lib/services/supabase_service.dart
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/product.dart';
import '../models/category.dart';
import '../models/transaction.dart';
import '../core/local_db.dart';

class SupabaseService {
  SupabaseService._();
  static final SupabaseService _instance = SupabaseService._();
  factory SupabaseService() => _instance;

  SupabaseClient get _client => Supabase.instance.client;
  final LocalDb _localDb = LocalDb.instance;
  static bool _isSyncing = false;
  static final Random _rng = Random();

  Future<AuthResponse> login(String email, String password) async {
    return await _client.auth
        .signInWithPassword(email: email, password: password);
  }

  /// Logout offline-safe:
  /// 1. Coba signOut global (invalidate token di server + clear lokal).
  /// 2. Jika gagal (offline / network error), fallback ke signOut lokal
  ///    (clear sesi dari SharedPreferences tanpa network call).
  /// 3. Jika keduanya gagal, tetap lanjut ke login screen — user tidak stuck.
  Future<void> logout() async {
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

  bool get isLoggedIn => _client.auth.currentSession != null;

  Future<List<Product>> getLocalProducts() => _localDb.getProducts();
  Future<List<Category>> getLocalCategories() => _localDb.getCategories();

  Future<void> syncData() async {
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

      // STEP 3.5: Remap product.category_id temp ids to real ids
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

      // STEP 5: Pull server categories (paginated)
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

      // STEP 6: Pull server products (paginated)
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
              // Rollback: hapus tx induk yang sudah terlanjur masuk
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
    } finally {
      _isSyncing = false;
    }
  }

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

  // ============ TRANSACTIONS ============

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