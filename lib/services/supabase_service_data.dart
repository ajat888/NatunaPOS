part of 'supabase_service.dart';
import '../models/voided_open_order.dart';

extension SupabaseServiceData on SupabaseService {
  Future<List<Product>> getLocalProducts() => _localDb.getProducts();
  Future<List<Product>> getLocalInactiveProducts() =>
      _localDb.getInactiveProducts();
  Future<List<Category>> getLocalCategories() => _localDb.getCategories();
  Future<List<Category>> getLocalInactiveCategories() =>
      _localDb.getInactiveCategories();

  Future<bool> isProductNameDuplicate(String name, {int? excludeId}) =>
      _localDb.isProductNameDuplicate(name, excludeId: excludeId);

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

  Future<void> restoreProduct(int id) async {
    await _localDb.restoreProduct(id);
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

  Future<void> restoreCategory(int id) async {
    await _localDb.restoreCategory(id);
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
      subtotal: total,
      createdAt: now,
      lines: lines,
    );
    await SyncStatusService.instance.refreshPendingCount();
  }

  Future<void> payOpenOrder({
    required String orderKey,
    required int cashReceived,
    required int changeAmount,
    required int billDiscount,
    required String discountType,
    required int discountValue,
    required double taxRate,
  }) async {
    final order = await _localDb.getOpenOrder(orderKey);
    if (order == null) throw Exception('Pesanan tidak ditemukan');

    final subtotal = order.subtotal;
    final safeDiscount = billDiscount.clamp(0, subtotal).toInt();
    final dasarPajak = subtotal - safeDiscount;
    final taxAmount = taxRate > 0 ? (dasarPajak * taxRate / 100).round() : 0;
    final grandTotal = dasarPajak + taxAmount;

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

    await _localDb.payOpenOrderAtomic(
      transactionId: transactionId,
      orderKey: orderKey,
      total: grandTotal,
      subtotal: subtotal,
      billDiscount: safeDiscount,
      discountType: discountType,
      discountValue: discountValue,
      taxRate: taxRate,
      taxAmount: taxAmount,
      createdAt: now,
      lines: lines,
      cashReceived: cashReceived,
      changeAmount: changeAmount,
      tableNumber: order.orderKey,
      orderType: order.orderType,
    );

    await SyncStatusService.instance.refreshPendingCount();
  }

  Future<void> payPartialOpenOrder({
    required String orderKey,
    required Map<int, int> selections,
    required int cashReceived,
    required int changeAmount,
    required int billDiscount,
    required String discountType,
    required int discountValue,
    required double taxRate,
  }) async {
    final order = await _localDb.getOpenOrder(orderKey);
    if (order == null) throw Exception('Pesanan tidak ditemukan');

    final itemsById = {for (final item in order.items) item.id: item};
    final lines = <TransactionLine>[];
    int subtotal = 0;
    for (final entry in selections.entries) {
      final item = itemsById[entry.key];
      if (item == null) continue;
      final qty = entry.value;
      if (qty <= 0) continue;
      subtotal += item.price * qty;
      lines.add(TransactionLine(
        productId: item.productId,
        productName: item.productName,
        price: item.price,
        hpp: item.hpp,
        qty: qty,
      ));
    }
    if (lines.isEmpty) throw Exception('Tidak ada item yang dipilih');

    final safeDiscount = billDiscount.clamp(0, subtotal).toInt();
    final dasarPajak = subtotal - safeDiscount;
    final taxAmount = taxRate > 0 ? (dasarPajak * taxRate / 100).round() : 0;
    final grandTotal = dasarPajak + taxAmount;

    final now = DateTime.now();
    final transactionId = -now.toUtc().microsecondsSinceEpoch;

    await _localDb.payPartialOpenOrderAtomic(
      transactionId: transactionId,
      orderKey: orderKey,
      total: grandTotal,
      subtotal: subtotal,
      billDiscount: safeDiscount,
      discountType: discountType,
      discountValue: discountValue,
      taxRate: taxRate,
      taxAmount: taxAmount,
      createdAt: now,
      lines: lines,
      selectionQtyByItemId: selections,
      cashReceived: cashReceived,
      changeAmount: changeAmount,
      tableNumber: order.orderKey,
      orderType: order.orderType,
    );

    await SyncStatusService.instance.refreshPendingCount();
  }

  Future<List<Transaction>> getLocalTransactions({int limit = 100}) async {
    return _localDb.getTransactions(limit: limit);
  }

  Future<Map<String, int>> getTodaySummary() async {
    return _localDb.getTodaySummary();
  }

  Future<void> voidTransaction({
    required int id,
    required String reason,
  }) async {
    final cashier = AppSettings.instance.cashierName.value.trim();
    final voidedBy = cashier.isEmpty ? 'Kasir' : cashier;
    await _localDb.voidTransaction(
      id: id,
      reason: reason.trim(),
      voidedBy: voidedBy,
    );
    await SyncStatusService.instance.refreshPendingCount();
    syncData();
  }

  Future<void> voidOpenOrder({
    required String orderKey,
    required String reason,
  }) async {
    final cashier = AppSettings.instance.cashierName.value.trim();
    final voidedBy = cashier.isEmpty ? 'Kasir' : cashier;
    await _localDb.voidOpenOrderWithArchive(
      orderKey: orderKey,
      reason: reason.trim(),
      voidedBy: voidedBy,
    );
  }

  Future<List<VoidedOpenOrder>> getLocalVoidedOpenOrders({int limit = 200}) =>
      _localDb.getVoidedOpenOrders(limit: limit);
}