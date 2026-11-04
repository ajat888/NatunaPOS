// lib/models/category.dart
class Category {
  final int id;
  final String name;
  final bool isSynced;
  final bool isDeleted;

  Category({
    required this.id,
    required this.name,
    this.isSynced = true,
    this.isDeleted = false,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    final active = json['is_active'] as bool? ?? true;
    return Category(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      isSynced: true,
      isDeleted: !active,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'is_active': !isDeleted,
    };
  }

  factory Category.fromDb(Map<String, dynamic> map) {
    return Category(
      id: map['id'] as int,
      name: map['name'] as String,
      isSynced: (map['is_synced'] as int? ?? 1) == 1,
      isDeleted: (map['is_deleted'] as int? ?? 0) == 1,
    );
  }

  Map<String, dynamic> toDb() {
    return {
      'id': id,
      'name': name,
      'is_synced': isSynced ? 1 : 0,
      'is_deleted': isDeleted ? 1 : 0,
    };
  }

  static const Object _sentinel = Object();

  Category copyWith({
    Object? id = _sentinel,
    Object? name = _sentinel,
    Object? isSynced = _sentinel,
    Object? isDeleted = _sentinel,
  }) {
    return Category(
      id: identical(id, _sentinel) ? this.id : id as int,
      name: identical(name, _sentinel) ? this.name : name as String,
      isSynced: identical(isSynced, _sentinel) ? this.isSynced : isSynced as bool,
      isDeleted: identical(isDeleted, _sentinel) ? this.isDeleted : isDeleted as bool,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Category && other.id == id);

  @override
  int get hashCode => id.hashCode;
}