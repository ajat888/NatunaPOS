// lib/models/open_order.dart

class OpenOrderLine {
  final int? productId;
  final String productName;
  final int price;
  final int hpp;
  final int qty;

  const OpenOrderLine({
    this.productId,
    required this.productName,
    required this.price,
    required this.hpp,
    required this.qty,
  });
}

class OpenOrderItem {
  final int id;
  final String orderKey;
  final int? productId;
  final String productName;
  final int price;
  final int hpp;
  final int qty;

  OpenOrderItem({
    required this.id,
    required this.orderKey,
    this.productId,
    required this.productName,
    required this.price,
    required this.hpp,
    required this.qty,
  });

  factory OpenOrderItem.fromDb(Map<String, dynamic> m) {
    return OpenOrderItem(
      id: m['id'] as int,
      orderKey: m['order_key'] as String,
      productId: (m['product_id'] as num?)?.toInt(),
      productName: m['product_name'] as String? ?? '',
      price: (m['price'] as num?)?.toInt() ?? 0,
      hpp: (m['hpp'] as num?)?.toInt() ?? 0,
      qty: (m['qty'] as num?)?.toInt() ?? 0,
    );
  }

  int get subtotal => price * qty;
}

class OpenOrder {
  final String orderKey;
  final String orderType; // 'dine_in' | 'take_away'
  final int? tableNumber; // null untuk take away
  final DateTime createdAt;
  final List<OpenOrderItem> items;

  OpenOrder({
    required this.orderKey,
    required this.orderType,
    this.tableNumber,
    required this.createdAt,
    required this.items,
  });

  int get total => items.fold(0, (s, e) => s + e.subtotal);
  int get itemCount => items.fold(0, (s, e) => s + e.qty);
  bool get isDineIn => orderType == 'dine_in';

  String get label {
    if (isDineIn && tableNumber != null) return 'Meja $tableNumber';
    return orderKey;
  }
}