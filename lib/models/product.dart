class Product {
  final int id;
  final String name;
  final int price;

  Product({
    required this.id,
    required this.name,
    required this.price,
  });

  // Untuk mengambil data dari Supabase (JSON)
  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      price: (json['price'] as num?)?.toInt() ?? 0,
    );
  }

  // Untuk mengirim data ke Supabase
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'price': price,
    };
  }

  // Untuk mengambil data dari SQLite (Database HP)
  factory Product.fromDb(Map<String, dynamic> map) {
    return Product(
      id: map['id'] as int,
      name: map['name'] as String,
      price: map['price'] as int,
    );
  }

  // Untuk menyimpan ke SQLite
  Map<String, dynamic> toDb() {
    return {
      'id': id,
      'name': name,
      'price': price,
    };
  }
}