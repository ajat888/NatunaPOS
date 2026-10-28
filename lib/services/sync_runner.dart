import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/local_db.dart';
import '../models/product.dart';
import '../models/category.dart';
import '../models/transaction.dart';

class SyncRunner {
  final SupabaseClient _client;
  final LocalDb _localDb;
  final Random _rng;

  SyncRunner({
    required SupabaseClient client,
    required LocalDb localDb,
    Random? rng,
  })  : _client = client,
        _localDb = localDb,
        _rng = rng ?? Random();

  Future<int> run() async {
    int failures = 0;

    // STEP 1: Hapus kategori di server (soft-delete flush)
    final deletedCategories = await _localDb.getDeletedCategories();
    for (final c in deletedCategories) {
      try {
        if (c.id > 0) {
          await _client.from('categories').delete().eq('id', c.id);
        }
        await _localDb.deleteCategory(c.id);
      } catch (e) {
        debugPrint('Sync delete category ${c.id} failed: $e');
        failures++;
      }
    }

    // STEP 2: Hapus produk di server (soft-delete flush)
    final deletedProducts = await _localDb.getDeletedProducts();
    for (final p in deletedProducts) {
      try {
        if (p.id > 0) {
          await _client.from('products').delete().eq('id', p.id);
        }
        await _localDb.deleteProduct(p.id);
      } catch (e) {
        debugPrint('Sync delete product ${p.id} failed: $e');
        failures++;
      }
    }

    // STEP 3: Push kategori baru / update
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
        failures++;
      }
    }

    // STEP 3.5: Remap product.category_id dari temp ID ke ID server
    for (final entry in categoryIdMap.entries) {
      try {
        await _localDb.remapProductCategory(entry.key, entry.value);
      } catch (e) {
        debugPrint('Remap category ${entry.key} -> ${entry.value} failed: $e');
        failures++;
      }
    }

    // STEP 4: Push produk (termasuk upload gambar fisik)
    final unsyncedProducts = await _localDb.getUnsyncedProducts();
    for (final p in unsyncedProducts) {
      try {
        String? finalImageUrl = p.imageUrl;
        String? remainingLocalImagePath = p.localImagePath;

        if (p.localImagePath != null &&
            File(p.localImagePath!).existsSync()) {
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
        failures++;
      }
    }

    // STEP 5: Pull semua kategori dari server
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
      failures++;
    }

    // STEP 6: Pull semua produk dari server
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
      failures++;
    }

    // STEP 7: Push transaksi lokal yang belum tersinkron
final unsyncedTransactions = await _localDb.getUnsyncedTransactions();
for (final tx in unsyncedTransactions) {
  try {
    if (tx.id < 0) {
      Map<String, dynamic> txResponse;
      try {
        txResponse = await _client
            .from('transactions')
            .insert({
              'total': tx.total,
              'created_at_local': tx.createdAt.millisecondsSinceEpoch,
              'cash_received': tx.cashReceived,
              'change_amount': tx.changeAmount,
              'table_number': tx.tableNumber,
              'order_type': tx.orderType,
            })
            .select()
            .single();
      } on PostgrestException catch (e) {
        // Fallback: kolom baru belum ada di server (kode 42703 = undefined_column).
        if (e.code == '42703' ||
            e.message.toLowerCase().contains('column')) {
          txResponse = await _client
              .from('transactions')
              .insert({
                'total': tx.total,
                'created_at_local':
                    tx.createdAt.millisecondsSinceEpoch,
              })
              .select()
              .single();
        } else {
          rethrow;
        }
      }
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
          await _client.from('transactions').delete().eq('id', serverTxId);
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
    failures++;
  }
}

    // STEP 8: Pull transaksi dari server (yang belum ada di lokal)
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

        final ids = list.map((e) => ((e as Map)['id'] as num).toInt()).toList();
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
      failures++;
    }

    return failures;
  }
}