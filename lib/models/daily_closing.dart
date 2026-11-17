class DailyClosing {
  final int id;
  final String closingDate;
  final int totalSales;
  final int totalTransactions;
  final int totalHpp;
  final int totalExpenses;
  final int totalVoidAmount;
  final int voidCount;
  final int cashExpected;
  final int cashActual;
  final int cashDifference;
  final String? closingNote;
  final String closedBy;
  final DateTime closedAt;
  final bool isSynced;

  DailyClosing({
    required this.id,
    required this.closingDate,
    required this.totalSales,
    required this.totalTransactions,
    required this.totalHpp,
    required this.totalExpenses,
    required this.totalVoidAmount,
    required this.voidCount,
    required this.cashExpected,
    required this.cashActual,
    required this.cashDifference,
    this.closingNote,
    required this.closedBy,
    required this.closedAt,
    this.isSynced = false,
  });

  factory DailyClosing.fromDb(Map<String, dynamic> m) => DailyClosing(
        id: m['id'] as int,
        closingDate: m['closing_date'] as String,
        totalSales: (m['total_sales'] as num).toInt(),
        totalTransactions: (m['total_transactions'] as num).toInt(),
        totalHpp: (m['total_hpp'] as num).toInt(),
        totalExpenses: (m['total_expenses'] as num).toInt(),
        totalVoidAmount: (m['total_void_amount'] as num).toInt(),
        voidCount: (m['void_count'] as num).toInt(),
        cashExpected: (m['cash_expected'] as num).toInt(),
        cashActual: (m['cash_actual'] as num).toInt(),
        cashDifference: (m['cash_difference'] as num).toInt(),
        closingNote: m['closing_note'] as String?,
        closedBy: (m['closed_by'] as String?) ?? '',
        closedAt: DateTime.fromMillisecondsSinceEpoch(
          (m['closed_at'] as num).toInt(),
          isUtc: true,
        ).toLocal(),
        isSynced: (m['is_synced'] as int? ?? 1) == 1,
      );

  factory DailyClosing.fromJson(Map<String, dynamic> json) {
    return DailyClosing(
      id: (json['id'] as num).toInt(),
      closingDate: json['closing_date'] as String,
      totalSales: (json['total_sales'] as num).toInt(),
      totalTransactions: (json['total_transactions'] as num).toInt(),
      totalHpp: (json['total_hpp'] as num).toInt(),
      totalExpenses: (json['total_expenses'] as num).toInt(),
      totalVoidAmount: (json['total_void_amount'] as num).toInt(),
      voidCount: (json['void_count'] as num).toInt(),
      cashExpected: (json['cash_expected'] as num).toInt(),
      cashActual: (json['cash_actual'] as num).toInt(),
      cashDifference: (json['cash_difference'] as num).toInt(),
      closingNote: json['closing_note'] as String?,
      closedBy: (json['closed_by'] as String?) ?? '',
      closedAt: DateTime.fromMillisecondsSinceEpoch(
        (json['closed_at'] as num).toInt(),
        isUtc: true,
      ).toLocal(),
      isSynced: true,
    );
  }

  Map<String, dynamic> toDb() => {
        'closing_date': closingDate,
        'total_sales': totalSales,
        'total_transactions': totalTransactions,
        'total_hpp': totalHpp,
        'total_expenses': totalExpenses,
        'total_void_amount': totalVoidAmount,
        'void_count': voidCount,
        'cash_expected': cashExpected,
        'cash_actual': cashActual,
        'cash_difference': cashDifference,
        'closing_note': closingNote,
        'closed_by': closedBy,
        'closed_at': closedAt.toUtc().millisecondsSinceEpoch,
        'is_synced': isSynced ? 1 : 0,
      };

  DailyClosing copyWith({
    int? id,
    String? closingDate,
    int? totalSales,
    int? totalTransactions,
    int? totalHpp,
    int? totalExpenses,
    int? totalVoidAmount,
    int? voidCount,
    int? cashExpected,
    int? cashActual,
    int? cashDifference,
    String? closingNote,
    String? closedBy,
    DateTime? closedAt,
    bool? isSynced,
  }) {
    return DailyClosing(
      id: id ?? this.id,
      closingDate: closingDate ?? this.closingDate,
      totalSales: totalSales ?? this.totalSales,
      totalTransactions: totalTransactions ?? this.totalTransactions,
      totalHpp: totalHpp ?? this.totalHpp,
      totalExpenses: totalExpenses ?? this.totalExpenses,
      totalVoidAmount: totalVoidAmount ?? this.totalVoidAmount,
      voidCount: voidCount ?? this.voidCount,
      cashExpected: cashExpected ?? this.cashExpected,
      cashActual: cashActual ?? this.cashActual,
      cashDifference: cashDifference ?? this.cashDifference,
      closingNote: closingNote ?? this.closingNote,
      closedBy: closedBy ?? this.closedBy,
      closedAt: closedAt ?? this.closedAt,
      isSynced: isSynced ?? this.isSynced,
    );
  }
}