// lib/services/report_service.dart
import '../core/local_db.dart';
import '../models/expense.dart';
import '../models/transaction.dart';
import '../models/voided_open_order.dart';

class ReportSummary {
  final DateTime from;
  final DateTime to;
  final int totalSales;
  final int totalTransactions;
  final int totalItems;
  final int totalHpp;
  final int totalExpenses;
  final int totalVoidAmount;
  final int voidTransactionCount;
  final int totalVoidOpenOrderAmount;
  final int voidOpenOrderCount;
  final int cashExpected;
  final List<Transaction> transactions;
  final List<Expense> expenses;
  final List<VoidedOpenOrder> voidedOpenOrders;
  final List<Map<String, dynamic>> topProducts;
  final List<Map<String, dynamic>> dailySales;

  ReportSummary({
    required this.from,
    required this.to,
    required this.totalSales,
    required this.totalTransactions,
    required this.totalItems,
    required this.totalHpp,
    required this.totalExpenses,
    required this.totalVoidAmount,
    required this.voidTransactionCount,
    required this.totalVoidOpenOrderAmount,
    required this.voidOpenOrderCount,
    required this.cashExpected,
    required this.transactions,
    required this.expenses,
    required this.voidedOpenOrders,
    required this.topProducts,
    required this.dailySales,
    required this.hourlySales,
  });

  int get grossProfit => totalSales - totalHpp;
  int get netProfit => grossProfit - totalExpenses;
  int get totalVoidCount => voidTransactionCount + voidOpenOrderCount;
}

class ReportService {
  ReportService._();
  static final ReportService instance = ReportService._();

  Future<ReportSummary> buildReport({
    required DateTime from,
    required DateTime to,
  }) async {
    final db = LocalDb.instance;
    final start = DateTime(from.year, from.month, from.day);
    final end =
        DateTime(to.year, to.month, to.day).add(const Duration(days: 1));

    final sales = await db.getSalesSummaryBetween(start, end);
    final hpp = await db.getHppBetween(start, end);
    final cash = await db.getCashExpectedBetween(start, end);
    final voidTx = await db.getVoidTransactionsSummaryBetween(start, end);
    final expSum = await db.getExpenseSummaryBetween(start, end);
    final transactions = await db.getTransactionsBetween(start, end);
    final expenses = await db.getExpensesBetween(start, end);
    final voidedOpenOrders = await db.getVoidedOpenOrdersBetween(start, end);
    
    final topProductsData = await db.getProductPerformanceBetween(start, end);
    topProductsData.sort((a, b) => (b['qty_sold'] as int).compareTo(a['qty_sold'] as int));
    
    final dailySalesData = await db.getDailySalesBreakdown(start, end);

// TAMBAHAN: Ambil data per jam jika rentang waktu hanya 1 hari
List<Map<String, dynamic>> hourlySalesData = [];
if (start.year == to.year && start.month == to.month && start.day == to.day) {
  hourlySalesData = await db.getHourlySalesBreakdown(start, end);
}

return ReportSummary(
  from: from,
  to: to,
  totalSales: sales['total'] ?? 0,
  totalTransactions: sales['count'] ?? 0,
  totalItems: sales['items'] ?? 0,
  totalHpp: hpp,
  totalExpenses: expSum['total'] ?? 0,
  totalVoidAmount: voidTx['total'] ?? 0,
  voidTransactionCount: voidTx['count'] ?? 0,
  totalVoidOpenOrderAmount: voidOpenAmount,
  voidOpenOrderCount: voidedOpenOrders.length,
  cashExpected: cash,
  transactions: transactions,
  expenses: expenses,
  voidedOpenOrders: voidedOpenOrders,
  topProducts: topProductsData,
  dailySales: dailySalesData,
  hourlySales: hourlySalesData, // <-- TAMBAHAN
);
  }
}