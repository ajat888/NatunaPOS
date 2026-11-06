class ExpenseCategory {
  final int id;
  final String name;
  final bool isSynced;
  final bool isDeleted;

  ExpenseCategory({
    required this.id,
    required this.name,
    this.isSynced = true,
    this.isDeleted = false,
  });

  factory ExpenseCategory.fromJson(Map<String, dynamic> json) {
    final active = json['is_active'] as bool? ?? true;
    return ExpenseCategory(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String? ?? '',
      isSynced: true,
      isDeleted: !active,
    );
  }

  factory ExpenseCategory.fromDb(Map<String, dynamic> map) {
    return ExpenseCategory(
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

  ExpenseCategory copyWith({
    Object? id = _sentinel,
    Object? name = _sentinel,
    Object? isSynced = _sentinel,
    Object? isDeleted = _sentinel,
  }) {
    return ExpenseCategory(
      id: identical(id, _sentinel) ? this.id : id as int,
      name: identical(name, _sentinel) ? this.name : name as String,
      isSynced: identical(isSynced, _sentinel) ? this.isSynced : isSynced as bool,
      isDeleted: identical(isDeleted, _sentinel) ? this.isDeleted : isDeleted as bool,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is ExpenseCategory && other.id == id);

  @override
  int get hashCode => id.hashCode;
}