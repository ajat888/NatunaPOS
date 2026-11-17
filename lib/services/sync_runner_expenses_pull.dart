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
    final lastPull = AppSettings.instance.lastPullTime;
    final unsynced = await _localDb.getUnsyncedExpenseCategories();
    final unsyncedIds = unsynced.map((e) => e.id).toSet();

    int offset = 0;
    const pageSize = 1000;
    while (true) {
      final response = await _client
          .from('expense_categories')
          .select()
          .eq('user_id', userId)
          .gt('updated_at', lastPull)
          .order('updated_at', ascending: true)
          .range(offset, offset + pageSize - 1);
      final list = (response as List)
          .map((j) => ExpenseCategory.fromJson(j))
          .toList();
      
      for (final c in list) {
        if (unsyncedIds.contains(c.id)) continue;
        await _localDb.upsertExpenseCategory(c, skipSync: true);
      }
      if (list.length < pageSize) break;
      offset += pageSize;
    }
    return 0;
  } catch (e) {
    debugPrint('Pull expense categories failed: $e');
    return 1;
  }
}

Future<int> pullItems(String userId) async {
  try {
    final lastPull = AppSettings.instance.lastPullTime;
    final unsynced = await _localDb.getUnsyncedExpenseItems();
    final unsyncedIds = unsynced.map((e) => e.id).toSet();

    int offset = 0;
    const pageSize = 1000;
    while (true) {
      final response = await _client
          .from('expense_items')
          .select()
          .eq('user_id', userId)
          .gt('updated_at', lastPull)
          .order('updated_at', ascending: true)
          .range(offset, offset + pageSize - 1);
      final list =
          (response as List).map((j) => ExpenseItem.fromJson(j)).toList();
      
      for (final it in list) {
        if (unsyncedIds.contains(it.id)) continue;
        await _localDb.upsertExpenseItem(it, skipSync: true);
      }
      if (list.length < pageSize) break;
      offset += pageSize;
    }
    return 0;
  } catch (e) {
    debugPrint('Pull expense items failed: $e');
    return 1;
  }
}

Future<int> pullExpenses(String userId) async {
  try {
    final lastPull = AppSettings.instance.lastPullTime;
    int offset = 0;
    const pageSize = 500;
    while (true) {
      final response = await _client
          .from('expenses')
          .select()
          .eq('user_id', userId)
          .gt('updated_at', lastPull)
          .order('updated_at', ascending: true)
          .range(offset, offset + pageSize - 1);
      final list = response as List;
      if (list.isEmpty) break;

      final unsyncedIds = await _localDb.getUnsyncedExpenseIds();
      for (final raw in list) {
        final m = raw as Map<String, dynamic>;
        final id = (m['id'] as num).toInt();
        if (unsyncedIds.contains(id)) continue;
        await _localDb.upsertPulledExpense(Expense.fromJson(m), skipSync: true);
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