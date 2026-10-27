class Product {
  final int id;
  final String name;
  final int price;
  final int hpp;
  final int? categoryId;
  final String? imageUrl;

  Product({
    required this.id,
    required this.name,
    required this.price,
    required this.hpp,
    this.categoryId,
    this.imageUrl,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      price: (json['price'] as num?)?.toInt() ?? 0,
      hpp: (json['hpp'] as num?)?.toInt() ?? 0,
      categoryId: (json['category_id'] as num?)?.toInt(),
      imageUrl: json['image_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'hpp': hpp,
      'category_id': categoryId,
      'image_url': imageUrl,
    };
  }

  factory Product.fromDb(Map<String, dynamic> map) {
    return Product(
      id: map['id'] as int,
      name: map['name'] as String,
      price: map['price'] as int,
      hpp: map['hpp'] as int? ?? 0,
      categoryId: map['category_id'] as int?,
      imageUrl: map['image_url'] as String?,
    );
  }

  Map<String, dynamic> toDb() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'hpp': hpp,
      'category_id': categoryId,
      'image_url': imageUrl,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Product && other.id == id);

  @override
  int get hashCode => id.hashCode;
}