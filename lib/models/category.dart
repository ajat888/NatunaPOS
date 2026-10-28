class Category {
  final int id;
  final String name;
  final bool isSynced;

  Category({
    required this.id,
    required this.name,
    this.isSynced = true,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      isSynced: true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
    };
  }

  factory Category.fromDb(Map<String, dynamic> map) {
    return Category(
      id: map['id'] as int,
      name: map['name'] as String,
      isSynced: (map['is_synced'] as int? ?? 1) == 1,
    );
  }

  Map<String, dynamic> toDb() {
    return {
      'id': id,
      'name': name,
      'is_synced': isSynced ? 1 : 0,
    };
  }

  Category copyWith({int? id, String? name, bool? isSynced}) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      isSynced: isSynced ?? this.isSynced,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Category && other.id == id);

  @override
  int get hashCode => id.hashCode;
}