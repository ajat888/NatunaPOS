// lib/services/sync_runner_open_orders.dart
part of 'sync_runner.dart';

class _SyncOpenOrder {
  final SupabaseClient _client;
  final LocalDb _localDb;

  _SyncOpenOrder(SyncRunner r)
      : _client = r.client,
        _localDb = r.localDb;

  /// Push order_key yang sudah di-pay/void ke server (hapus dari server).
  /// Kalau berhasil, hapus dari queue delete lokal agar tidak diulang.
  Future<int> pushDeletes() async {
    int failures = 0;
    final keys = await _localDb.getDeletedOpenOrderKeys();
    if (keys.isEmpty) return 0;

    for (final key in keys) {
      try {
        final existing = await _client
            .from('open_orders')
            .select('id')
            .eq('order_key', key)
            .limit(1);

        if ((existing as List).isNotEmpty) {
          final serverId = ((existing.first as Map)['id'] as num).toInt();
          await _client.from('open_orders').delete().eq('id', serverId);
        }

        await _localDb.removeDeletedOpenOrderKey(key);
      } catch (e) {
        debugPrint('Push delete open order $key failed: $e');
        failures++;
      }
    }
    return failures;
  }

  /// Push semua open order lokal sebagai upsert (create/update). Item
  /// di-replace total (delete + insert) untuk kesederhanaan.
  Future<int> pushUpserts() async {
    int failures = 0;
    final orders = await _localDb.getOpenOrders();
    if (orders.isEmpty) return 0;

    Map<String, int> serverIdByKey = {};
    try {
      final serverOrders =
          await _client.from('open_orders').select('id, order_key');
      for (final row in (serverOrders as List)) {
        final m = row as Map<String, dynamic>;
        serverIdByKey[m['order_key'] as String] = (m['id'] as num).toInt();
      }
    } catch (e) {
      debugPrint('Fetch server open order ids failed: $e');
      return 1;
    }

    for (final order in orders) {
      try {
        final existingId = serverIdByKey[order.orderKey];
        int serverOrderId;

        if (existingId != null) {
          await _client.from('open_orders').update({
            'order_type': order.orderType,
            'table_number': order.tableNumber,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          }).eq('id', existingId);
          serverOrderId = existingId;
        } else {
          try {
            final response = await _client
                .from('open_orders')
                .insert({
                  'order_key': order.orderKey,
                  'order_type': order.orderType,
                  'table_number': order.tableNumber,
                  'created_at_local': order.createdAt.millisecondsSinceEpoch,
                })
                .select()
                .single();
            serverOrderId = (response['id'] as num).toInt();
          } on PostgrestException catch (e) {
            if (e.code == '23505') {
              final res = await _client
                  .from('open_orders')
                  .select('id')
                  .eq('order_key', order.orderKey)
                  .single();
              serverOrderId = (res['id'] as num).toInt();
            } else {
              rethrow;
            }
          }
        }

        await _client
            .from('open_order_items')
            .delete()
            .eq('open_order_id', serverOrderId);

        for (final item in order.items) {
          final pushProductId =
              (item.productId != null && item.productId! > 0)
                  ? item.productId
                  : null;
          try {
            await _client.from('open_order_items').insert({
              'open_order_id': serverOrderId,
              'product_id': pushProductId,
              'product_name': item.productName,
              'price': item.price,
              'hpp': item.hpp,
              'qty': item.qty,
            });
          } on PostgrestException catch (e) {
            if (e.code == '23503' && pushProductId != null) {
              await _client.from('open_order_items').insert({
                'open_order_id': serverOrderId,
                'product_id': null,
                'product_name': item.productName,
                'price': item.price,
                'hpp': item.hpp,
                'qty': item.qty,
              });
            } else {
              rethrow;
            }
          }
        }
      } catch (e) {
        debugPrint('Push open order ${order.orderKey} failed: $e');
        failures++;
      }
    }
    return failures;
  }

  /// Pull open order dari server. Insert ke lokal jika belum ada dan
  /// tidak sedang dalam antrean delete.
  Future<int> pull() async {
    try {
      final response = await _client.from('open_orders').select(
          'id, order_key, order_type, table_number, created_at_local, '
          'open_order_items(product_id, product_name, price, hpp, qty)');

      for (final raw in (response as List)) {
        final m = raw as Map<String, dynamic>;
        final orderKey = m['order_key'] as String;

        final rawItems =
            (m['open_order_items'] as List?) ?? const <dynamic>[];
        final lines = rawItems.map<OpenOrderLine>((i) {
          final im = i as Map<String, dynamic>;
          return OpenOrderLine(
            productId: (im['product_id'] as num?)?.toInt(),
            productName: im['product_name'] as String? ?? '',
            price: (im['price'] as num?)?.toInt() ?? 0,
            hpp: (im['hpp'] as num?)?.toInt() ?? 0,
            qty: (im['qty'] as num?)?.toInt() ?? 0,
          );
        }).toList();

        final createdAtMs = (m['created_at_local'] as num?)?.toInt() ??
            DateTime.now().millisecondsSinceEpoch;

        await _localDb.insertPulledOpenOrder(
          orderKey: orderKey,
          orderType: m['order_type'] as String? ?? 'dine_in',
          tableNumber: (m['table_number'] as num?)?.toInt(),
          createdAt: DateTime.fromMillisecondsSinceEpoch(createdAtMs),
          lines: lines,
        );
      }
      return 0;
    } catch (e) {
      debugPrint('Pull open orders failed: $e');
      return 1;
    }
  }
}