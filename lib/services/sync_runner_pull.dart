part of 'sync_runner.dart';

class _SyncPuller {
  final SupabaseClient _client;
  final LocalDb _localDb;

  _SyncPuller(SyncRunner r)
      : _client = r.client,
        _localDb = r.localDb;

  Future<int> pullAll() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return 0;

    int failures = 0;
    failures += await _pullCategories(userId);
    failures += await _pullProducts(userId);
    failures += await _pullTransactions(userId);
    return failures;
  }

  Future<int> _pullCategories(String userId) async {
    try {
      final all = <Category>[];
      int offset = 0;
      const pageSize = 1000;
      while (true) {
        final response = await _client
            .from('categories')
            .select()
            .eq('user_id', userId)
            .order('id', ascending: true)
            .range(offset, offset + pageSize - 1);
        final list =
            (response as List).map((j) => Category.fromJson(j)).toList();
        all.addAll(list);
        if (list.length < pageSize) break;
        offset += pageSize;
      }
      await _localDb.replaceAllCategories(all, skipSync: true);
      return 0;
    } catch (e) {
      debugPrint('Pull categories failed: $e');
      return 1;
    }
  }

  Future<int> _pullProducts(String userId) async {
    try {
      final all = <Product>[];
      int offset = 0;
      const pageSize = 1000;
      while (true) {
        final response = await _client
            .from('products')
            .select()
            .eq('user_id', userId)
            .order('id', ascending: true)
            .range(offset, offset + pageSize - 1);
        final list =
            (response as List).map((j) => Product.fromJson(j)).toList();
        all.addAll(list);
        if (list.length < pageSize) break;
        offset += pageSize;
      }
      await _localDb.replaceAllProducts(all, skipSync: true);
      await _downloadMissingImages();
      return 0;
    } catch (e) {
      debugPrint('Pull products failed: $e');
      return 1;
    }
  }

  Future<void> _downloadMissingImages() async {
    try {
      final missing = await _localDb.getProductsNeedingImageDownload();
      if (missing.isEmpty) return;

      final dir = await getApplicationDocumentsDirectory();
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      for (final product in missing) {
        try {
          final url = product.imageUrl;
          if (url == null || url.isEmpty) continue;

          final response = await http
              .get(Uri.parse(url))
              .timeout(const Duration(seconds: 15));
          if (response.statusCode != 200) {
            debugPrint('Download image product ${product.id}: HTTP ${response.statusCode}');
            continue;
          }

          final filename =
              'img_${DateTime.now().microsecondsSinceEpoch}_${product.id}.jpg';
          final file = File('${dir.path}/$filename');
          await file.writeAsBytes(response.bodyBytes);

          await _localDb.updateProductLocalImagePath(product.id, file.path, skipSync: true);
          debugPrint('Downloaded image for product ${product.id}');
        } catch (e) {
          debugPrint('Download image product ${product.id} failed: $e');
        }
      }
    } catch (e) {
      debugPrint('_downloadMissingImages failed: $e');
    }
  }

  int? _parseTimestamp(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toInt();
    return DateTime.tryParse(v.toString())?.millisecondsSinceEpoch;
  }

  Future<int> _pullTransactions(String userId) async {
    try {
      int offset = 0;
      const pageSize = 500;
      while (true) {
        List<dynamic> list = const [];
        try {
          final response = await _client
              .from('transactions')
              .select(
                  'id, total, subtotal, bill_discount, discount_type, discount_value, tax_rate, tax_amount, created_at_local, cash_received, change_amount, table_number, order_type, parent_order_key, is_voided, void_reason, voided_by, voided_at, transaction_items(product_id, product_name, price, hpp, qty)')
              .eq('user_id', userId)
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
                    'id, total, subtotal, bill_discount, discount_type, discount_value, tax_rate, tax_amount, created_at_local, cash_received, change_amount, table_number, order_type, parent_order_key, transaction_items(product_id, product_name, price, hpp, qty)')
                .eq('user_id', userId)
                .order('id', ascending: true)
                .range(offset, offset + pageSize - 1);
            list = response as List;
          } on PostgrestException catch (e2) {
            if (!(e2.code == '42703' ||
                e2.message.toLowerCase().contains('column'))) {
              rethrow;
            }
            try {
              final response = await _client
                  .from('transactions')
                  .select(
                      'id, total, created_at_local, cash_received, change_amount, table_number, order_type, transaction_items(product_id, product_name, price, hpp, qty)')
                  .eq('user_id', userId)
                  .order('id', ascending: true)
                  .range(offset, offset + pageSize - 1);
              list = response as List;
            } on PostgrestException catch (e3) {
              if (!(e3.code == '42703' ||
                  e3.message.toLowerCase().contains('column'))) {
                rethrow;
              }
              final response = await _client
                  .from('transactions')
                  .select(
                      'id, total, created_at_local, transaction_items(product_id, product_name, price, hpp, qty)')
                  .eq('user_id', userId)
                  .order('id', ascending: true)
                  .range(offset, offset + pageSize - 1);
              list = response as List;
            }
          }
        }

        if (list.isEmpty) break;
        final ids =
            list.map((e) => ((e as Map)['id'] as num).toInt()).toList();
        final existing = await _localDb.existingTransactionIds(ids);

        for (final raw in list) {
          final m = raw as Map<String, dynamic>;
          final id = (m['id'] as num).toInt();
          if (existing.contains(id)) {
  final isVoided = (m['is_voided'] as bool?) ?? false;
  if (isVoided) {
    await _localDb.updateVoidedTransactionFromPull(
      id: id,
      isVoided: isVoided,
      voidReason: m['void_reason'] as String?,
      voidedBy: m['voided_by'] as String?,
      voidedAtMs: _parseTimestamp(m['voided_at']),
      skipSync: true,
    );
  }
  continue;
}

          final rawItems =
              (m['transaction_items'] as List?) ?? const <dynamic>[];
          final items = rawItems.map<TransactionLine>((i) {
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
            subtotal: (m['subtotal'] as num?)?.toInt() ?? 0,
            billDiscount: (m['bill_discount'] as num?)?.toInt() ?? 0,
            discountType: (m['discount_type'] as String?) ?? 'nominal',
            discountValue: (m['discount_value'] as num?)?.toInt() ?? 0,
            taxRate: (m['tax_rate'] as num?)?.toDouble() ?? 0,
            taxAmount: (m['tax_amount'] as num?)?.toInt() ?? 0,
            createdAtLocalMs: createdAtMs,
            items: items,
            cashReceived: (m['cash_received'] as num?)?.toInt() ?? 0,
            changeAmount: (m['change_amount'] as num?)?.toInt() ?? 0,
            tableNumber: m['table_number'] as String?,
            orderType: m['order_type'] as String?,
            parentOrderKey: m['parent_order_key'] as String?,
            isVoided: (m['is_voided'] as bool?) ?? false,
            voidReason: m['void_reason'] as String?,
            voidedBy: m['voided_by'] as String?,
            voidedAtMs: _parseTimestamp(m['voided_at']),
            skipSync: true,
          );
        }
        if (list.length < pageSize) break;
        offset += pageSize;
      }
      return 0;
    } catch (e) {
      debugPrint('Pull transactions failed: $e');
      return 1;
    }
  }
}