part of 'sync_runner.dart';

class _SyncPuller {
  final SupabaseClient _client;
  final LocalDb _localDb;

  _SyncPuller(SyncRunner r)
      : _client = r.client,
        _localDb = r.localDb;

Future<({int failures, String? maxUpdatedAt})> pullAll() async {
  final userId = _client.auth.currentUser?.id;
  if (userId == null) return (failures: 0, maxUpdatedAt: null);

  int failures = 0;
  String? maxUpdatedAt;

  final lastCleanup = DateTime.tryParse(AppSettings.instance.lastCleanupTime) ?? DateTime(1970);
  final needCleanup = DateTime.now().difference(lastCleanup).inHours >= 24;

  final catRes = await _pullCategories(userId);
  failures += catRes.failures;
  maxUpdatedAt = _maxStr(maxUpdatedAt, catRes.maxUpdatedAt);
  if (catRes.failures == 0 && needCleanup) await _cleanupOrphanCategories(userId);

  final prodRes = await _pullProducts(userId);
  failures += prodRes.failures;
  maxUpdatedAt = _maxStr(maxUpdatedAt, prodRes.maxUpdatedAt);
  if (prodRes.failures == 0 && needCleanup) await _cleanupOrphanProducts(userId);

  final txRes = await _pullTransactions(userId);
  failures += txRes.failures;
  maxUpdatedAt = _maxStr(maxUpdatedAt, txRes.maxUpdatedAt);

  if (failures == 0 && needCleanup) {
    await AppSettings.instance.setLastCleanupTime(DateTime.now().toUtc().toIso8601String());
  }

  return (failures: failures, maxUpdatedAt: maxUpdatedAt);
}

  String? _maxStr(String? current, String? incoming) {
    if (incoming == null) return current;
    if (current == null) return incoming;
    return incoming.compareTo(current) > 0 ? incoming : current;
  }

  String _pullWatermarkWithOverlap(String raw) {
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    return parsed.toUtc().subtract(const Duration(minutes: 5)).toIso8601String();
  }

  Future<void> _cleanupOrphanCategories(String userId) async {
  try {
    final serverIds = <int>[];
    int offset = 0;
    const pageSize = 1000;
    while (true) {
      final response = await _client
          .from('categories')
          .select('id')
          .eq('user_id', userId)
          .order('id', ascending: true)
          .range(offset, offset + pageSize - 1);
      final list = response as List;
      serverIds.addAll(list.map((e) => (e['id'] as num).toInt()));
      if (list.length < pageSize) break;
      offset += pageSize;
    }
    await _localDb.markMissingCategoriesAsDeleted(serverIds);
  } catch (e) {
    debugPrint('Cleanup orphan categories failed: $e');
  }
}

Future<void> _cleanupOrphanProducts(String userId) async {
  try {
    final serverIds = <int>[];
    int offset = 0;
    const pageSize = 1000;
    while (true) {
      final response = await _client
          .from('products')
          .select('id')
          .eq('user_id', userId)
          .order('id', ascending: true)
          .range(offset, offset + pageSize - 1);
      final list = response as List;
      serverIds.addAll(list.map((e) => (e['id'] as num).toInt()));
      if (list.length < pageSize) break;
      offset += pageSize;
    }
    await _localDb.markMissingProductsAsDeleted(serverIds);
  } catch (e) {
    debugPrint('Cleanup orphan products failed: $e');
  }
}

  Future<({int failures, String? maxUpdatedAt})> _pullCategories(String userId) async {
    try {
      final lastPull = AppSettings.instance.lastPullTime;
      final unsynced = await _localDb.getUnsyncedCategories();
      final unsyncedIds = unsynced.map((e) => e.id).toSet();
      String? maxUpdatedAt;

      int offset = 0;
      const pageSize = 1000;
      while (true) {
        final response = await _client
            .from('categories')
            .select()
            .eq('user_id', userId)
            .gt('updated_at', lastPull)
            .order('updated_at', ascending: true)
            .range(offset, offset + pageSize - 1);
        final list = (response as List).map((j) => Category.fromJson(j)).toList();
        final rawList = response;
        
        for (int i = 0; i < list.length; i++) {
          final c = list[i];
          final raw = rawList[i];
          if (raw['updated_at'] != null) {
            maxUpdatedAt = _maxStr(maxUpdatedAt, raw['updated_at'] as String);
          }
          if (unsyncedIds.contains(c.id)) continue;
          await _localDb.upsertCategory(c, skipSync: true);
        }
        if (list.length < pageSize) break;
        offset += pageSize;
      }
      return (failures: 0, maxUpdatedAt: maxUpdatedAt);
    } catch (e) {
      debugPrint('Pull categories failed: $e');
      return (failures: 1, maxUpdatedAt: null);
    }
  }

  Future<({int failures, String? maxUpdatedAt})> _pullProducts(String userId) async {
    try {
      final lastPull = AppSettings.instance.lastPullTime;
      final unsyncedIds = await _localDb.getPendingProductIds();
      String? maxUpdatedAt;

      int offset = 0;
      const pageSize = 1000;
      while (true) {
        final response = await _client
            .from('products')
            .select()
            .eq('user_id', userId)
            .gt('updated_at', lastPull)
            .order('updated_at', ascending: true)
            .range(offset, offset + pageSize - 1);
        final list = (response as List).map((j) => Product.fromJson(j)).toList();
        final rawList = response;

        for (int i = 0; i < list.length; i++) {
          final p = list[i];
          final raw = rawList[i];
          if (raw['updated_at'] != null) {
            maxUpdatedAt = _maxStr(maxUpdatedAt, raw['updated_at'] as String);
          }
          if (unsyncedIds.contains(p.id)) continue;
          await _localDb.upsertProduct(p, skipSync: true);
        }
        if (list.length < pageSize) break;
        offset += pageSize;
      }
      await _downloadMissingImages();
      return (failures: 0, maxUpdatedAt: maxUpdatedAt);
    } catch (e) {
      debugPrint('Pull products failed: $e');
      return (failures: 1, maxUpdatedAt: null);
    }
  }

  Future<void> _downloadMissingImages() async {
    if (kIsWeb) return;
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
            debugPrint(
                'Download image product ${product.id}: HTTP ${response.statusCode}');
            continue;
          }

          final filename =
              'img_${DateTime.now().microsecondsSinceEpoch}_${product.id}.jpg';
          final file = File('${dir.path}/$filename');
          await file.writeAsBytes(response.bodyBytes);

          await _localDb.updateProductLocalImagePath(product.id, file.path,
              skipSync: true);
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

  Future<({int failures, String? maxUpdatedAt})> _pullTransactions(String userId) async {
    try {
      final lastPull = _pullWatermarkWithOverlap(AppSettings.instance.lastTxPullTime);
      int offset = 0;
      const pageSize = 500;
      String? maxUpdatedAt;

      while (true) {
const query = 'id, total, subtotal, bill_discount, discount_type, discount_value, tax_rate, tax_amount, created_at_local, cash_received, change_amount, table_number, order_type, parent_order_key, payment_method, is_voided, void_reason, voided_by, voided_at, updated_at, transaction_items(product_id, product_name, price, hpp, qty)';
        final response = await _client
            .from('transactions')
            .select(query)
            .eq('user_id', userId)
            .gt('updated_at', lastPull)
            .order('updated_at', ascending: true)
            .range(offset, offset + pageSize - 1);
        final List<dynamic> list = response as List;
        String? pageMax;

        if (list.isEmpty) break;
        final ids = list.map((e) => ((e as Map)['id'] as num).toInt()).toList();
        final existing = await _localDb.existingTransactionIds(ids);

        for (final raw in list) {
          final m = raw as Map<String, dynamic>;
          if (m['updated_at'] != null) {
            maxUpdatedAt = _maxStr(maxUpdatedAt, m['updated_at'] as String);
            pageMax = _maxStr(pageMax, m['updated_at'] as String);
          }
          
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

          final rawItems = (m['transaction_items'] as List?) ?? const <dynamic>[];
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
            createdAtMs = DateTime.tryParse(rawLocal)?.millisecondsSinceEpoch ?? 0;
          } else if (m['created_at'] != null) {
            final rawCreated = m['created_at'];
            if (rawCreated is num) {
              createdAtMs = rawCreated.toInt();
            } else {
              createdAtMs = DateTime.tryParse(rawCreated.toString())?.millisecondsSinceEpoch ?? 0;
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
            paymentMethod: m['payment_method'] as String?,
            isVoided: (m['is_voided'] as bool?) ?? false,
            voidReason: m['void_reason'] as String?,
            voidedBy: m['voided_by'] as String?,
            voidedAtMs: _parseTimestamp(m['voided_at']),
            skipSync: true,
          );
        }
        if (pageMax != null) {
          await AppSettings.instance.setLastTxPullTime(pageMax);
        }
        if (list.length < pageSize) break;
        offset += pageSize;
      }
      return (failures: 0, maxUpdatedAt: maxUpdatedAt);
    } catch (e) {
      debugPrint('Pull transactions failed: $e');
      return (failures: 1, maxUpdatedAt: null);
    }
  }
}