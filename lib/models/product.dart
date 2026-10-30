// lib/models/product.dart
class Product {
  final int id;
  final String name;
  final int price;
  final int hpp;
  final int? categoryId;
  final String? imageUrl;
  final String? localImagePath;
  final bool isSynced;

  Product({
    required this.id,
    required this.name,
    required this.price,
    required this.hpp,
    this.categoryId,
    this.imageUrl,
    this.localImagePath,
    this.isSynced = true,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      price: (json['price'] as num?)?.toInt() ?? 0,
      hpp: (json['hpp'] as num?)?.toInt() ?? 0,
      categoryId: (json['category_id'] as num?)?.toInt(),
      imageUrl: json['image_url'] as String?,
      isSynced: true,
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
      localImagePath: map['local_image_path'] as String?,
      isSynced: (map['is_synced'] as int? ?? 1) == 1,
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
      'local_image_path': localImagePath,
      'is_synced': isSynced ? 1 : 0,
    };
  }

  static const Object _sentinel = Object();

  Product copyWith({
    int? id,
    String? name,
    int? price,
    int? hpp,
    Object? categoryId = _sentinel,
    Object? imageUrl = _sentinel,
    Object? localImagePath = _sentinel,
    bool? isSynced,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      hpp: hpp ?? this.hpp,
      categoryId: identical(categoryId, _sentinel) 
          ? this.categoryId 
          : categoryId as int?,
      imageUrl: identical(imageUrl, _sentinel) 
          ? this.imageUrl 
          : imageUrl as String?,
      localImagePath: identical(localImagePath, _sentinel) 
          ? this.localImagePath 
          : localImagePath as String?,
      isSynced: isSynced ?? this.isSynced,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Product && other.id == id);

  @override
  int get hashCode => id.hashCode;
}