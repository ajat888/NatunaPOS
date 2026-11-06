class Expense {
  final int id;
  final int? itemId;
  final String itemName;
  final int? categoryId;
  final String categoryName;
  final int amount;
  final String? description;
  final DateTime createdAt;
  final String createdBy;
  final bool isSynced;
  final bool isDeleted;

  Expense({
    required this.id,
    this.itemId,
    required this.itemName,
    this.categoryId,
    required this.categoryName,
    required this.amount,
    this.description,
    required this.createdAt,
    required this.createdBy,
    this.isSynced = true,
    this.isDeleted = false,
  });

  factory Expense.fromJson(Map<String, dynamic> json) {
    final active = json['is_active'] as bool? ?? true;
    int createdMs = 0;
    final rawLocal = json['created_at_local'];
    if (rawLocal is num) {
      createdMs = rawLocal.toInt();
    } else if (rawLocal is String) {
      createdMs = DateTime.tryParse(rawLocal)?.millisecondsSinceEpoch ?? 0;
    }
    return Expense(
      id: (json['id'] as num).toInt(),
      itemId: (json['item_id'] as num?)?.toInt(),
      itemName: json['item_name'] as String? ?? '',
      categoryId: (json['category_id'] as num?)?.toInt(),
      categoryName: json['category_name'] as String? ?? '',
      amount: (json['amount'] as num?)?.toInt() ?? 0,
      description: json['description'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(createdMs),
      createdBy: json['created_by'] as String? ?? '',
      isSynced: true,
      isDeleted: !active,
    );
  }

  factory Expense.fromDb(Map<String, dynamic> map) {
    return Expense(
      id: map['id'] as int,
      itemId: (map['item_id'] as num?)?.toInt(),
      itemName: map['item_name'] as String,
      categoryId: (map['category_id'] as num?)?.toInt(),
      categoryName: map['category_name'] as String,
      amount: (map['amount'] as num).toInt(),
      description: map['description'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        map['created_at'] as int,
        isUtc: true,
      ).toLocal(),
      createdBy: map['created_by'] as String? ?? '',
      isSynced: (map['is_synced'] as int? ?? 1) == 1,
      isDeleted: (map['is_deleted'] as int? ?? 0) == 1,
    );
  }

  Map<String, dynamic> toDb() {
    return {
      'id': id,
      'item_id': itemId,
      'item_name': itemName,
      'category_id': categoryId,
      'category_name': categoryName,
      'amount': amount,
      'description': description,
      'created_at': createdAt.toUtc().millisecondsSinceEpoch,
      'created_by': createdBy,
      'is_synced': isSynced ? 1 : 0,
      'is_deleted': isDeleted ? 1 : 0,
    };
  }

  static const Object _sentinel = Object();

  Expense copyWith({
    int? id,
    Object? itemId = _sentinel,
    String? itemName,
    Object? categoryId = _sentinel,
    String? categoryName,
    int? amount,
    Object? description = _sentinel,
    DateTime? createdAt,
    String? createdBy,
    bool? isSynced,
    bool? isDeleted,
  }) {
    return Expense(
      id: id ?? this.id,
      itemId: identical(itemId, _sentinel) ? this.itemId : itemId as int?,
      itemName: itemName ?? this.itemName,
      categoryId: identical(categoryId, _sentinel) ? this.categoryId : categoryId as int?,
      categoryName: categoryName ?? this.categoryName,
      amount: amount ?? this.amount,
      description: identical(description, _sentinel) ? this.description : description as String?,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
      isSynced: isSynced ?? this.isSynced,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Expense && other.id == id);

  @override
  int get hashCode => id.hashCode;
}