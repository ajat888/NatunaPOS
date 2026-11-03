// lib/services/sync_runner_push.dart
part of 'sync_runner.dart';

class _SyncPusher {
  final SupabaseClient _client;
  final LocalDb _localDb;
  final Random _rng;

  _SyncPusher(SyncRunner r)
      : _client = r.client,
        _localDb = r.localDb,
        _rng = r.rng;

  Future<int> pushAll() async {
    int failures = 0;
    failures += await _pushDeletedCategories();
    failures += await _pushDeletedProducts();
    final catRes = await _pushCategories();
    failures += catRes.failures;
    failures += await _remapProductCategories(catRes.categoryIdMap);
    failures += await _pushProducts(catRes.categoryIdMap);
    failures += await _pushTransactions();
    return failures;
  }

  Future<int> _pushDeletedCategories() async {
    int failures = 0;
    final deleted = await _localDb.getDeletedCategories();
    for (final c in deleted) {
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
    return failures;
  }

  Future<int> _pushDeletedProducts() async {
    int failures = 0;
    final deleted = await _localDb.getDeletedProducts();
    for (final p in deleted) {
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
    return failures;
  }

  Future<({int failures, Map<int, int> categoryIdMap})> _pushCategories() async {
    int failures = 0;
    final map = <int, int>{};
    final unsynced = await _localDb.getUnsyncedCategories();
    for (final c in unsynced) {
      try {
        if (c.id < 0) {
          int? existingId;
          try {
            final probe = await _client
                .from('categories')
                .select('id')
                .eq('name', c.name)
                .limit(1);
            if ((probe as List).isNotEmpty) {
              existingId = (probe.first['id'] as num).toInt();
            }
          } catch (e) {
            debugPrint('Category idempotency probe failed: $e');
          }

          int newId;
          Map<String, dynamic> response;
          if (existingId != null) {
            newId = existingId;
            response = {'id': newId, 'name': c.name};
          } else {
            response = await _client
                .from('categories')
                .insert({'name': c.name})
                .select()
                .single();
            newId = response['id'] as int;
          }
          map[c.id] = newId;
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
    return (failures: failures, categoryIdMap: map);
  }

  Future<int> _remapProductCategories(Map<int, int> map) async {
    int failures = 0;
    for (final entry in map.entries) {
      try {
        await _localDb.remapProductCategory(entry.key, entry.value);
      } catch (e) {
        debugPrint('Remap category ${entry.key} -> ${entry.value} failed: $e');
        failures++;
      }
    }
    return failures;
  }

  Future<int> _pushProducts(Map<int, int> categoryIdMap) async {
    int failures = 0;
    final unsynced = await _localDb.getUnsyncedProducts();
    for (final p in unsynced) {
      try {
        String? finalImageUrl = p.imageUrl;
        String? remainingLocal = p.localImagePath;

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
          remainingLocal = null;
        } else if (p.localImagePath != null) {
          debugPrint(
              'WARNING: Local image missing for product "${p.name}" (${p.id})');
          remainingLocal = null;
        }

        int? finalCategoryId = p.categoryId;
        if (finalCategoryId != null &&
            categoryIdMap.containsKey(finalCategoryId)) {
          finalCategoryId = categoryIdMap[finalCategoryId];
        }

        if (p.id < 0) {
          int? existingId;
          try {
            final probe = await _client
                .from('products')
                .select('id')
                .eq('name', p.name)
                .eq('price', p.price)
                .limit(1);
            if ((probe as List).isNotEmpty) {
              existingId = (probe.first['id'] as num).toInt();
            }
          } catch (e) {
            debugPrint('Product idempotency probe failed: $e');
          }

          int newId;
          Product serverProduct;
          if (existingId != null) {
            newId = existingId;
            serverProduct = Product(
              id: newId,
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
            newId = (response['id'] as num).toInt();
            serverProduct = Product.fromJson(response);
          }

          await _localDb.transactionalReplaceProduct(
            oldId: p.id,
            newProduct: serverProduct,
            newServerId: newId,
          );
        } else {
          await _client.from('products').upsert({
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
            localImagePath: remainingLocal,
            isSynced: true,
          ));
        }
      } catch (e) {
        debugPrint('Sync product ${p.id} failed: $e');
        failures++;
      }
    }
    return failures;
  }

  Future<int> _pushTransactions() async {
    int failures = 0;
    final unsynced = await _localDb.getUnsyncedTransactions();
    for (final tx in unsynced) {
      try {
        if (tx.id >= 0) continue;
        final localCreatedMs = tx.createdAt.millisecondsSinceEpoch;

        // Semua kolom dikirim selalu. Tidak ada fallback: jika schema
        // belum lengkap, insert gagal dan transaksi tetap antre (is_synced = 0).
        final Map<String, dynamic> payload = {
          'total': tx.total,
          'subtotal': tx.subtotal,
          'bill_discount': tx.billDiscount,
          'discount_type': tx.discountType,
          'discount_value': tx.discountValue,
          'tax_rate': tx.taxRate,
          'tax_amount': tx.taxAmount,
          'created_at_local': localCreatedMs,
          'cash_received': tx.cashReceived,
          'change_amount': tx.changeAmount,
          'table_number': tx.tableNumber,
          'order_type': tx.orderType,
        };

        int? existingId;
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
            existingId = ((matches.first as Map)['id'] as num).toInt();
          }
        } catch (e) {
          debugPrint('Idempotency probe failed for tx ${tx.id}: $e');
        }

        int serverTxId;
        if (existingId != null) {
          // Transaksi sudah ada di server (kemungkinan insert sebelumnya
          // terputus). Perbarui baris termasuk kolom pajak, lalu ganti item.
          serverTxId = existingId;
          await _client
              .from('transactions')
              .update(payload)
              .eq('id', serverTxId);
          await _client
              .from('transaction_items')
              .delete()
              .eq('transaction_id', serverTxId);
        } else {
          final response = await _client
              .from('transactions')
              .insert(payload)
              .select()
              .single();
          serverTxId = (response['id'] as num).toInt();
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

        await _localDb.replaceTransactionId(oldId: tx.id, newId: serverTxId);
      } catch (e) {
        debugPrint('Sync transaction ${tx.id} failed: $e');
        failures++;
      }
    }
    return failures;
  }
}