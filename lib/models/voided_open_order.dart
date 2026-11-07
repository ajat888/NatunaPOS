import 'dart:convert';

class VoidedOpenOrderItem {
  final int? productId;
  final String productName;
  final int price;
  final int hpp;
  final int qty;

  const VoidedOpenOrderItem({
    this.productId,
    required this.productName,
    required this.price,
    required this.hpp,
    required this.qty,
  });

  factory VoidedOpenOrderItem.fromJson(Map<String, dynamic> m) {
    return VoidedOpenOrderItem(
      productId: (m['product_id'] as num?)?.toInt(),
      productName: m['product_name'] as String? ?? '',
      price: (m['price'] as num?)?.toInt() ?? 0,
      hpp: (m['hpp'] as num?)?.toInt() ?? 0,
      qty: (m['qty'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'product_id': productId,
        'product_name': productName,
        'price': price,
        'hpp': hpp,
        'qty': qty,
      };

  int get subtotal => price * qty;
}

class VoidedOpenOrder {
  final int id;
  final String orderKey;
  final String orderType;
  final int? tableNumber;
  final int subtotal;
  final int itemCount;
  final List<VoidedOpenOrderItem> items;
  final String voidReason;
  final String voidedBy;
  final DateTime voidedAt;
  final DateTime createdAt;

  VoidedOpenOrder({
    required this.id,
    required this.orderKey,
    required this.orderType,
    this.tableNumber,
    required this.subtotal,
    required this.itemCount,
    required this.items,
    required this.voidReason,
    required this.voidedBy,
    required this.voidedAt,
    required this.createdAt,
  });

  String get label {
    if (orderType == 'dine_in' && tableNumber != null) {
      return 'Meja $tableNumber';
    }
    return orderKey;
  }

  factory VoidedOpenOrder.fromDb(Map<String, dynamic> m) {
    List<VoidedOpenOrderItem> items = [];
    try {
      final raw = jsonDecode((m['items_json'] as String?) ?? '[]');
      if (raw is List) {
        items = raw
            .map((e) =>
                VoidedOpenOrderItem.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {
      items = [];
    }
    return VoidedOpenOrder(
      id: m['id'] as int,
      orderKey: m['order_key'] as String,
      orderType: m['order_type'] as String,
      tableNumber: (m['table_number'] as num?)?.toInt(),
      subtotal: (m['subtotal'] as num?)?.toInt() ?? 0,
      itemCount: (m['item_count'] as num?)?.toInt() ?? 0,
      items: items,
      voidReason: m['void_reason'] as String? ?? '',
      voidedBy: m['voided_by'] as String? ?? '',
      voidedAt: DateTime.fromMillisecondsSinceEpoch(
        (m['voided_at'] as num).toInt(),
        isUtc: true,
      ).toLocal(),
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (m['created_at'] as num).toInt(),
        isUtc: true,
      ).toLocal(),
    );
  }

  Map<String, dynamic> toDb() => {
        'order_key': orderKey,
        'order_type': orderType,
        'table_number': tableNumber,
        'subtotal': subtotal,
        'item_count': itemCount,
        'items_json': jsonEncode(items.map((e) => e.toJson()).toList()),
        'void_reason': voidReason,
        'voided_by': voidedBy,
        'voided_at': voidedAt.toUtc().millisecondsSinceEpoch,
        'created_at': createdAt.toUtc().millisecondsSinceEpoch,
      };
}