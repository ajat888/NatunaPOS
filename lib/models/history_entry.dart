import 'expense.dart';
import 'transaction.dart';

enum HistoryKind { sale, expense }

class HistoryEntry {
  final HistoryKind kind;
  final DateTime createdAt;
  final Transaction? transaction;
  final Expense? expense;

  HistoryEntry._({
    required this.kind,
    required this.createdAt,
    this.transaction,
    this.expense,
  });

  factory HistoryEntry.fromSale(Transaction tx) => HistoryEntry._(
        kind: HistoryKind.sale,
        createdAt: tx.createdAt,
        transaction: tx,
      );

  factory HistoryEntry.fromExpense(Expense exp) => HistoryEntry._(
        kind: HistoryKind.expense,
        createdAt: exp.createdAt,
        expense: exp,
      );
}