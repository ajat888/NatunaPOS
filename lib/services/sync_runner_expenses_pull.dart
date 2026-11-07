part of 'sync_runner.dart';

class _SyncExpensesPuller {
  final SupabaseClient _client;
  final LocalDb _localDb;

  _SyncExpensesPuller(SyncRunner r)
      : _client = r.client,
        _localDb = r.localDb;

  Future<int> pullAll() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return 0;

    int failures = 0;
    failures += await pullCategories(userId);
    failures += await pullItems(userId);
    failures += await pullExpenses(userId);
    return failures;
  }

  Future<int> pullCategories(String userId) async {
    try {
      final all = <ExpenseCategory>[];
      int offset = 0;
      const pageSize = 1000;
      while (true) {
        final response = await _client
            .from('expense_categories')
            .select()
            .eq('user_id', userId)
            .order('id', ascending: true)
            .range(offset, offset + pageSize - 1);
        final list = (response as List)
            .map((j) => ExpenseCategory.fromJson(j))
            .toList();
        all.addAll(list);
        if (list.length < pageSize) break;
        offset += pageSize;
      }
      await _localDb.replaceAllExpenseCategories(all);
      return 0;
    } catch (e) {
      debugPrint('Pull expense categories failed: $e');
      return 1;
    }
  }

  Future<int> pullItems(String userId) async {
    try {
      final all = <ExpenseItem>[];
      int offset = 0;
      const pageSize = 1000;
      while (true) {
        final response = await _client
            .from('expense_items')
            .select()
            .eq('user_id', userId)
            .order('id', ascending: true)
            .range(offset, offset + pageSize - 1);
        final list =
            (response as List).map((j) => ExpenseItem.fromJson(j)).toList();
        all.addAll(list);
        if (list.length < pageSize) break;
        offset += pageSize;
      }
      await _localDb.replaceAllExpenseItems(all);
      return 0;
    } catch (e) {
      debugPrint('Pull expense items failed: $e');
      return 1;
    }
  }

  Future<int> pullExpenses(String userId) async {
    try {
      int offset = 0;
      const pageSize = 500;
      while (true) {
        final response = await _client
            .from('expenses')
            .select()
            .eq('user_id', userId)
            .order('id', ascending: true)
            .range(offset, offset + pageSize - 1);
        final list = response as List;
        if (list.isEmpty) break;

        final unsyncedIds = await _localDb.getUnsyncedExpenseIds();
        for (final raw in list) {
          final m = raw as Map<String, dynamic>;
          final id = (m['id'] as num).toInt();
          if (unsyncedIds.contains(id)) continue;
          await _localDb.upsertPulledExpense(Expense.fromJson(m));
        }
        if (list.length < pageSize) break;
        offset += pageSize;
      }
      return 0;
    } catch (e) {
      debugPrint('Pull expenses failed: $e');
      return 1;
    }
  }
}