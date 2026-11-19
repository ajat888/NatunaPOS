// lib/models/product.dart
import 'dart:math';

class Product {
  final int id;
  final String name;
  final int price;
  final int hpp;
  final int? categoryId;
  final String? imageUrl;
  final String? localImagePath;
  final bool isSynced;
  final bool isDeleted;
  final String? clientUuid;

  Product({
    required this.id,
    required this.name,
    required this.price,
    required this.hpp,
    this.categoryId,
    this.imageUrl,
    this.localImagePath,
    this.isSynced = true,
    this.isDeleted = false,
    this.clientUuid,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    final active = json['is_active'] as bool? ?? true;
    return Product(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      price: (json['price'] as num?)?.toInt() ?? 0,
      hpp: (json['hpp'] as num?)?.toInt() ?? 0,
      categoryId: (json['category_id'] as num?)?.toInt(),
      imageUrl: json['image_url'] as String?,
      isSynced: true,
      isDeleted: !active,
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
      'is_active': !isDeleted,
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
      isDeleted: (map['is_deleted'] as int? ?? 0) == 1,
      clientUuid: map['client_uuid'] as String?,
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
      'is_deleted': isDeleted ? 1 : 0,
      'client_uuid': clientUuid,
    };
  }

  static String generateClientUuid() {
    final rng = Random.secure();
    final b = List<int>.generate(16, (_) => rng.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40;
    b[8] = (b[8] & 0x3f) | 0x80;
    final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-'
        '${h.substring(16, 20)}-${h.substring(20)}';
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
    bool? isDeleted,
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
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Product && other.id == id);

  @override
  int get hashCode => id.hashCode;
}