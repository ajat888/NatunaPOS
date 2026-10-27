import 'package:syncable/syncable.dart';

class Product extends SyncableEntity {
  String name;
  int price;

  Product({
    super.id, // ID dari Supabase
    required this.name,
    required this.price,
    super.createdAt,
    super.updatedAt,
    super.deleted,
  });

  // Konversi dari JSON Supabase (untuk sinkronisasi)
  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id']?.toString(),
      name: json['name'] as String? ?? '',
      price: (json['price'] as num?)?.toInt() ?? 0,
    );
  }

  // Konversi ke JSON untuk dikirim ke Supabase
  @override
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'price': price,
    };
  }

  // Konversi dari Database SQLite (untuk dibaca aplikasi)
  factory Product.fromDb(Map<String, dynamic> map) {
    return Product(
      id: map['id']?.toString(),
      name: map['name'] as String,
      price: map['price'] as int,
    );
  }

  // Konversi ke Database SQLite
  Map<String, dynamic> toDb() {
    return {
      'id': id,
      'name': name,
      'price': price,
    };
  }
}