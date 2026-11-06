class ExpenseItem {
  final int id;
  final int categoryId;
  final String name;
  final bool isSynced;
  final bool isDeleted;

  ExpenseItem({
    required this.id,
    required this.categoryId,
    required this.name,
    this.isSynced = true,
    this.isDeleted = false,
  });

  factory ExpenseItem.fromJson(Map<String, dynamic> json) {
    final active = json['is_active'] as bool? ?? true;
    return ExpenseItem(
      id: (json['id'] as num).toInt(),
      categoryId: (json['category_id'] as num).toInt(),
      name: json['name'] as String? ?? '',
      isSynced: true,
      isDeleted: !active,
    );
  }

  factory ExpenseItem.fromDb(Map<String, dynamic> map) {
    return ExpenseItem(
      id: map['id'] as int,
      categoryId: (map['category_id'] as num).toInt(),
      name: map['name'] as String,
      isSynced: (map['is_synced'] as int? ?? 1) == 1,
      isDeleted: (map['is_deleted'] as int? ?? 0) == 1,
    );
  }

  Map<String, dynamic> toDb() {
    return {
      'id': id,
      'category_id': categoryId,
      'name': name,
      'is_synced': isSynced ? 1 : 0,
      'is_deleted': isDeleted ? 1 : 0,
    };
  }

  static const Object _sentinel = Object();

  ExpenseItem copyWith({
    Object? id = _sentinel,
    Object? categoryId = _sentinel,
    Object? name = _sentinel,
    Object? isSynced = _sentinel,
    Object? isDeleted = _sentinel,
  }) {
    return ExpenseItem(
      id: identical(id, _sentinel) ? this.id : id as int,
      categoryId: identical(categoryId, _sentinel) ? this.categoryId : categoryId as int,
      name: identical(name, _sentinel) ? this.name : name as String,
      isSynced: identical(isSynced, _sentinel) ? this.isSynced : isSynced as bool,
      isDeleted: identical(isDeleted, _sentinel) ? this.isDeleted : isDeleted as bool,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is ExpenseItem && other.id == id);

  @override
  int get hashCode => id.hashCode;
}