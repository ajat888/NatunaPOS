// lib/models/daily_closing.dart
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
}