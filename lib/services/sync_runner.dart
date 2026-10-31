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
        await _localDb.markProductSyncedAndDeleted(p.id);
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
          int? existingServerId;
          try {
            final probe = await _client
                .from('categories')
                .select('id')
                .eq('name', c.name)
                .limit(1);
            if ((probe as List).isNotEmpty) {
              existingServerId = (probe.first['id'] as num).toInt();
            }
          } catch (e) {
            debugPrint('Category idempotency probe failed: $e');
          }

          int newId;
          Map<String, dynamic> response;
          if (existingServerId != null) {
            newId = existingServerId;
            response = {'id': newId, 'name': c.name};
          } else {
            response = await _client
                .from('categories')
                .insert({'name': c.name})
                .select()
                .single();
            newId = response['id'] as int;
          }
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
        } else if (p.localImagePath != null) {
          debugPrint(
              'WARNING: Local image missing for product "${p.name}" (${p.id}) '
              'at ${p.localImagePath}. Proceeding without upload.');
          remainingLocalImagePath = null;
        }

        int? finalCategoryId = p.categoryId;
        if (finalCategoryId != null &&
            categoryIdMap.containsKey(finalCategoryId)) {
          finalCategoryId = categoryIdMap[finalCategoryId];
        }

        if (p.id < 0) {
          int? existingServerId;
          try {
            final probe = await _client
                .from('products')
                .select('id')
                .eq('name', p.name)
                .eq('price', p.price)
                .limit(1);
            if ((probe as List).isNotEmpty) {
              existingServerId = (probe.first['id'] as num).toInt();
            }
          } catch (e) {
            debugPrint('Product idempotency probe failed: $e');
          }

          int newProductId;
          Product serverProduct;
          if (existingServerId != null) {
            newProductId = existingServerId;
            serverProduct = Product(
              id: newProductId,
              name: p.name,
              price: p.price,
              hpp: p.hpp,
              categoryId: finalCategoryId,
              imageUrl: finalImageUrl,
              isSynced: true,
            );
          } else {
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
            newProductId = (response['id'] as num).toInt();
            serverProduct = Product.fromJson(response);
          }

          await _localDb.transactionalReplaceProduct(
            oldId: p.id,
            newProduct: serverProduct,
            newServerId: newProductId,
          );
        } else {
          // FIX: Gunakan upsert agar jika produk sudah dihapus di server (misal: restore),
          // produk bisa dibuat ulang tanpa error.
          await _client
              .from('products')
              .upsert({
                'id': p.id,
                'name': p.name,
                'price': p.price,
                'hpp': p.hpp,
                'category_id': finalCategoryId,
                'image_url': finalImageUrl,
              });
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
        if (tx.id >= 0) continue;

        final localCreatedMs = tx.createdAt.millisecondsSinceEpoch;

        int? existingServerId;
        try {
          final probe = await _client
              .from('transactions')
              .select('id, total')
              .eq('created_at_local', localCreatedMs)
              .limit(5);
          final matches = (probe as List).where((e) {
            final t = ((e as Map)['total'] as num?)?.toInt();
            return t == tx.total;
          }).toList();
          if (matches.isNotEmpty) {
            existingServerId = ((matches.first as Map)['id'] as num).toInt();
            debugPrint(
                'Idempotency: tx ${tx.id} already on server as $existingServerId');
          }
        } on PostgrestException catch (e) {
          if (e.code != '42703' && !e.message.toLowerCase().contains('column')) {
            debugPrint('Idempotency probe failed for tx ${tx.id}: $e');
          }
        }

        int serverTxId;
        if (existingServerId != null) {
          serverTxId = existingServerId;
          try {
            await _client
                .from('transaction_items')
                .delete()
                .eq('transaction_id', serverTxId);
          } catch (e) {
            debugPrint('Cleanup old items for tx $serverTxId failed: $e');
          }
        } else {
          Map<String, dynamic> txResponse;
          try {
            txResponse = await _client
                .from('transactions')
                .insert({
                  'total': tx.total,
                  'created_at_local': localCreatedMs,
                  'cash_received': tx.cashReceived,
                  'change_amount': tx.changeAmount,
                  'table_number': tx.tableNumber,
                  'order_type': tx.orderType,
                })
                .select()
                .single();
          } on PostgrestException catch (e) {
            if (e.code == '42703' ||
                e.message.toLowerCase().contains('column')) {
              txResponse = await _client
                  .from('transactions')
                  .insert({
                    'total': tx.total,
                    'created_at_local': localCreatedMs,
                  })
                  .select()
                  .single();
            } else {
              rethrow;
            }
          }
          serverTxId = txResponse['id'] as int;
        }

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

        await _localDb.replaceTransactionId(
          oldId: tx.id,
          newId: serverTxId,
        );
      } catch (e) {
        debugPrint('Sync transaction ${tx.id} failed: $e');
        failures++;
      }
    }

    // STEP 8: Pull transaksi dari server
    try {
      int offset = 0;
      const pageSize = 500;
      while (true) {
        List<dynamic> list = const [];
        try {
          final response = await _client
              .from('transactions')
              .select(
                  'id, total, created_at_local, cash_received, change_amount, table_number, order_type, transaction_items(product_id, product_name, price, hpp, qty)')
              .order('id', ascending: true)
              .range(offset, offset + pageSize - 1);
          list = response as List;
        } on PostgrestException catch (e) {
          if (!(e.code == '42703' ||
              e.message.toLowerCase().contains('column'))) {
            rethrow;
          }
          try {
            final response = await _client
                .from('transactions')
                .select(
                    'id, total, created_at_local, transaction_items(product_id, product_name, price, hpp, qty)')
                .order('id', ascending: true)
                .range(offset, offset + pageSize - 1);
            list = response as List;
          } on PostgrestException catch (e2) {
            if (!(e2.code == '42703' ||
                e2.message.toLowerCase().contains('column'))) {
              rethrow;
            }
            final response = await _client
                .from('transactions')
                .select(
                    'id, total, created_at, transaction_items(product_id, product_name, price, hpp, qty)')
                .order('id', ascending: true)
                .range(offset, offset + pageSize - 1);
            list = response as List;
          }
        }

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

          int createdAtMs = 0;
          final rawLocal = m['created_at_local'];
          if (rawLocal is num) {
            createdAtMs = rawLocal.toInt();
          } else if (rawLocal is String) {
            createdAtMs =
                DateTime.tryParse(rawLocal)?.millisecondsSinceEpoch ?? 0;
          } else if (m['created_at'] != null) {
            final rawCreated = m['created_at'];
            if (rawCreated is num) {
              createdAtMs = rawCreated.toInt();
            } else {
              createdAtMs = DateTime.tryParse(rawCreated.toString())
                      ?.millisecondsSinceEpoch ??
                  0;
            }
          }

          await _localDb.insertPulledTransaction(
            id: id,
            total: (m['total'] as num?)?.toInt() ?? 0,
            createdAtLocalMs: createdAtMs,
            items: items,
            cashReceived: (m['cash_received'] as num?)?.toInt() ?? 0,
            changeAmount: (m['change_amount'] as num?)?.toInt() ?? 0,
            tableNumber: m['table_number'] as String?,
            orderType: m['order_type'] as String?,
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