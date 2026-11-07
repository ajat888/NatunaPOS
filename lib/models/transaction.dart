// lib/models/transaction.dart

class TransactionLine {
  final int? productId;
  final String productName;
  final int price;
  final int hpp;
  final int qty;

  const TransactionLine({
    this.productId,
    required this.productName,
    required this.price,
    required this.hpp,
    required this.qty,
  });
}

class TransactionItem {
  final int id;
  final int transactionId;
  final int? productId;
  final String productName;
  final int price;
  final int hpp;
  final int qty;

  TransactionItem({
    required this.id,
    required this.transactionId,
    this.productId,
    required this.productName,
    required this.price,
    required this.hpp,
    required this.qty,
  });

  factory TransactionItem.fromDb(Map<String, dynamic> m) {
    return TransactionItem(
      id: m['id'] as int,
      transactionId: m['transaction_id'] as int,
      productId: (m['product_id'] as num?)?.toInt(),
      productName: m['product_name'] as String? ?? '',
      price: (m['price'] as num?)?.toInt() ?? 0,
      hpp: (m['hpp'] as num?)?.toInt() ?? 0,
      qty: (m['qty'] as num?)?.toInt() ?? 0,
    );
  }

  int get subtotal => price * qty;
}

class Transaction {
  final int id;
  final int total;
  final int subtotal;
  final int billDiscount;
  final String discountType;
  final int discountValue;
  final double taxRate;
  final int taxAmount;
  final DateTime createdAt;
  final bool isSynced;
  final List<TransactionItem> items;
  final int cashReceived;
  final int changeAmount;
  final String? tableNumber;
  final String? orderType;
  final String? parentOrderKey;
  final bool isVoided;
  final String? voidReason;
  final String? voidedBy;
  final DateTime? voidedAt;

  static const Object _sentinel = Object();

  Transaction({
    required this.id,
    required this.total,
    this.subtotal = 0,
    this.billDiscount = 0,
    this.discountType = 'nominal',
    this.discountValue = 0,
    this.taxRate = 0,
    this.taxAmount = 0,
    required this.createdAt,
    required this.isSynced,
    required this.items,
    this.cashReceived = 0,
    this.changeAmount = 0,
    this.tableNumber,
    this.orderType,
    this.parentOrderKey,
    this.isVoided = false,
    this.voidReason,
    this.voidedBy,
    this.voidedAt,
  });

  factory Transaction.fromDb(
    Map<String, dynamic> m,
    List<TransactionItem> items,
  ) {
    final rawVoidedAt = m['voided_at'];
    DateTime? parsedVoidedAt;
    if (rawVoidedAt is num) {
      parsedVoidedAt = DateTime.fromMillisecondsSinceEpoch(
        rawVoidedAt.toInt(),
        isUtc: true,
      ).toLocal();
    } else if (rawVoidedAt is String) {
      parsedVoidedAt = DateTime.tryParse(rawVoidedAt)?.toLocal();
    }

    return Transaction(
      id: m['id'] as int,
      total: (m['total'] as num?)?.toInt() ?? 0,
      subtotal: (m['subtotal'] as num?)?.toInt() ?? 0,
      billDiscount: (m['bill_discount'] as num?)?.toInt() ?? 0,
      discountType: (m['discount_type'] as String?) ?? 'nominal',
      discountValue: (m['discount_value'] as num?)?.toInt() ?? 0,
      taxRate: (m['tax_rate'] as num?)?.toDouble() ?? 0,
      taxAmount: (m['tax_amount'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        m['created_at'] as int,
        isUtc: true,
      ).toLocal(),
      isSynced: (m['is_synced'] as int? ?? 0) == 1,
      items: items,
      cashReceived: (m['cash_received'] as num?)?.toInt() ?? 0,
      changeAmount: (m['change_amount'] as num?)?.toInt() ?? 0,
      tableNumber: m['table_number'] as String?,
      orderType: m['order_type'] as String?,
      parentOrderKey: m['parent_order_key'] as String?,
      isVoided: (m['is_voided'] as int? ?? 0) == 1,
      voidReason: m['void_reason'] as String?,
      voidedBy: m['voided_by'] as String?,
      voidedAt: parsedVoidedAt,
    );
  }

  int get itemCount => items.fold(0, (s, e) => s + e.qty);

  bool get isSplit => parentOrderKey != null;

  Transaction copyWith({
    int? id,
    int? total,
    int? subtotal,
    int? billDiscount,
    String? discountType,
    int? discountValue,
    double? taxRate,
    int? taxAmount,
    DateTime? createdAt,
    bool? isSynced,
    List<TransactionItem>? items,
    int? cashReceived,
    int? changeAmount,
    Object? tableNumber = _sentinel,
    Object? orderType = _sentinel,
    Object? parentOrderKey = _sentinel,
    bool? isVoided,
    Object? voidReason = _sentinel,
    Object? voidedBy = _sentinel,
    Object? voidedAt = _sentinel,
  }) {
    return Transaction(
      id: id ?? this.id,
      total: total ?? this.total,
      subtotal: subtotal ?? this.subtotal,
      billDiscount: billDiscount ?? this.billDiscount,
      discountType: discountType ?? this.discountType,
      discountValue: discountValue ?? this.discountValue,
      taxRate: taxRate ?? this.taxRate,
      taxAmount: taxAmount ?? this.taxAmount,
      createdAt: createdAt ?? this.createdAt,
      isSynced: isSynced ?? this.isSynced,
      items: items ?? this.items,
      cashReceived: cashReceived ?? this.cashReceived,
      changeAmount: changeAmount ?? this.changeAmount,
      tableNumber: identical(tableNumber, _sentinel)
          ? this.tableNumber
          : tableNumber as String?,
      orderType: identical(orderType, _sentinel)
          ? this.orderType
          : orderType as String?,
      parentOrderKey: identical(parentOrderKey, _sentinel)
          ? this.parentOrderKey
          : parentOrderKey as String?,
      isVoided: isVoided ?? this.isVoided,
      voidReason: identical(voidReason, _sentinel)
          ? this.voidReason
          : voidReason as String?,
      voidedBy: identical(voidedBy, _sentinel)
          ? this.voidedBy
          : voidedBy as String?,
      voidedAt: identical(voidedAt, _sentinel)
          ? this.voidedAt
          : voidedAt as DateTime?,
    );
  }
}