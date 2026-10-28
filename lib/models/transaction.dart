// lib/models/transaction.dart

/// Input model untuk menyimpan transaksi baru (belum punya ID).
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

/// Model baris item transaksi yang dibaca dari SQLite.
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

/// Model transaksi lengkap (dengan items).
class Transaction {
  final int id;
  final int total;
  final DateTime createdAt;
  final bool isSynced;
  final List<TransactionItem> items;

  Transaction({
    required this.id,
    required this.total,
    required this.createdAt,
    required this.isSynced,
    required this.items,
  });

  factory Transaction.fromDb(
    Map<String, dynamic> m,
    List<TransactionItem> items,
  ) {
    return Transaction(
      id: m['id'] as int,
      total: (m['total'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        m['created_at'] as int,
        isUtc: true,
      ).toLocal(),
      isSynced: (m['is_synced'] as int? ?? 0) == 1,
      items: items,
    );
  }

  int get itemCount => items.fold(0, (s, e) => s + e.qty);
}