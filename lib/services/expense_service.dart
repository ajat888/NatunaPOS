import '../core/local_db.dart';
import '../models/expense.dart';
import '../models/expense_category.dart';
import '../models/expense_item.dart';
import 'write_notifier.dart';

class ExpenseService {
  ExpenseService._();
  static final ExpenseService instance = ExpenseService._();

  final LocalDb _localDb = LocalDb.instance;

  Future<void> createExpenseCategory(String name) async {
    final tempId = -DateTime.now().millisecondsSinceEpoch;
    await _localDb.upsertExpenseCategory(
        ExpenseCategory(id: tempId, name: name.trim(), isSynced: false));
    await WriteNotifier.notify();
  }

  Future<void> updateExpenseCategory(
      {required int id, required String name}) async {
    await _localDb.upsertExpenseCategory(
        ExpenseCategory(id: id, name: name.trim(), isSynced: false));
    await WriteNotifier.notify();
  }

  Future<void> deleteExpenseCategory(int id) async {
    await _localDb.markExpenseCategoryDeleted(id);
    await WriteNotifier.notify();
  }

  Future<void> restoreExpenseCategory(int id) async {
    await _localDb.restoreExpenseCategory(id);
    await WriteNotifier.notify();
  }

  Future<void> createExpenseItem(
      {required int categoryId, required String name}) async {
    final tempId = -DateTime.now().millisecondsSinceEpoch;
    await _localDb.upsertExpenseItem(ExpenseItem(
      id: tempId,
      categoryId: categoryId,
      name: name.trim(),
      isSynced: false,
    ));
    await WriteNotifier.notify();
  }

  Future<void> updateExpenseItem(
      {required int id,
      required int categoryId,
      required String name}) async {
    await _localDb.upsertExpenseItem(ExpenseItem(
      id: id,
      categoryId: categoryId,
      name: name.trim(),
      isSynced: false,
    ));
    await WriteNotifier.notify();
  }

  Future<void> deleteExpenseItem(int id) async {
    await _localDb.markExpenseItemDeleted(id);
    await WriteNotifier.notify();
  }

  Future<void> restoreExpenseItem(int id) async {
    await _localDb.restoreExpenseItem(id);
    await WriteNotifier.notify();
  }

  Future<void> createExpense({
    required int categoryId,
    required String categoryName,
    required int itemId,
    required String itemName,
    required int amount,
    String? description,
    required String createdBy,
  }) async {
    final now = DateTime.now();
    final tempId = -now.toUtc().millisecondsSinceEpoch;
    await _localDb.insertExpense(Expense(
      id: tempId,
      categoryId: categoryId,
      categoryName: categoryName,
      itemId: itemId,
      itemName: itemName,
      amount: amount,
      description: (description == null || description.trim().isEmpty)
          ? null
          : description.trim(),
      createdAt: now,
      createdBy: createdBy,
      isSynced: false,
    ));
    await WriteNotifier.notify();
  }

  Future<void> voidExpense(int id) async {
    await _localDb.markExpenseDeleted(id);
    await WriteNotifier.notify();
  }

  Future<List<Expense>> getLocalExpenses({int limit = 200}) =>
      _localDb.getExpenses(limit: limit);

  Future<int> getTodayExpenseTotal() => _localDb.getTodayExpenseTotal();

  Future<List<ExpenseCategory>> getLocalExpenseCategories() =>
      _localDb.getExpenseCategories();

  Future<List<ExpenseCategory>> getLocalInactiveExpenseCategories() =>
      _localDb.getInactiveExpenseCategories();

  Future<List<ExpenseItem>> getLocalExpenseItems() =>
      _localDb.getExpenseItems();

  Future<List<ExpenseItem>> getLocalInactiveExpenseItems() =>
      _localDb.getInactiveExpenseItems();

  Future<List<ExpenseItem>> getLocalExpenseItemsForInput() =>
      _localDb.getExpenseItemsForInput();

  Future<bool> isExpenseCategoryNameDuplicate(String name, {int? excludeId}) =>
      _localDb.isExpenseCategoryNameDuplicate(name, excludeId: excludeId);

  Future<bool> isExpenseItemNameDuplicate(String name, int categoryId,
          {int? excludeId}) =>
      _localDb.isExpenseItemNameDuplicate(name, categoryId,
          excludeId: excludeId);
}