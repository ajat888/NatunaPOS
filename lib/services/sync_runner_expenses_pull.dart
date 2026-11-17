part of 'sync_runner.dart';

class _SyncExpensesPuller {
  final SupabaseClient _client;
  final LocalDb _localDb;

  _SyncExpensesPuller(SyncRunner r)
      : _client = r.client,
        _localDb = r.localDb;

  Future<({int failures, String? maxUpdatedAt})> pullAll() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return (failures: 0, maxUpdatedAt: null);

    int failures = 0;
    String? maxUpdatedAt;

    final catRes = await pullCategories(userId);
    failures += catRes.failures;
    maxUpdatedAt = _maxStr(maxUpdatedAt, catRes.maxUpdatedAt);

    final itemRes = await pullItems(userId);
    failures += itemRes.failures;
    maxUpdatedAt = _maxStr(maxUpdatedAt, itemRes.maxUpdatedAt);

    final expRes = await pullExpenses(userId);
    failures += expRes.failures;
    maxUpdatedAt = _maxStr(maxUpdatedAt, expRes.maxUpdatedAt);

    return (failures: failures, maxUpdatedAt: maxUpdatedAt);
  }

  String? _maxStr(String? current, String? incoming) {
    if (incoming == null) return current;
    if (current == null) return incoming;
    return incoming.compareTo(current) > 0 ? incoming : current;
  }

  Future<({int failures, String? maxUpdatedAt})> pullCategories(String userId) async {
    try {
      final lastPull = AppSettings.instance.lastPullTime;
      final unsynced = await _localDb.getUnsyncedExpenseCategories();
      final unsyncedIds = unsynced.map((e) => e.id).toSet();
      String? maxUpdatedAt;

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
        final list = (response as List).map((j) => ExpenseCategory.fromJson(j)).toList();
        final rawList = response;

        for (int i = 0; i < list.length; i++) {
          final c = list[i];
          final raw = rawList[i];
          if (raw['updated_at'] != null) {
            maxUpdatedAt = _maxStr(maxUpdatedAt, raw['updated_at'] as String);
          }
          if (unsyncedIds.contains(c.id)) continue;
          await _localDb.upsertExpenseCategory(c, skipSync: true);
        }
        if (list.length < pageSize) break;
        offset += pageSize;
      }
      return (failures: 0, maxUpdatedAt: maxUpdatedAt);
    } catch (e) {
      debugPrint('Pull expense categories failed: $e');
      return (failures: 1, maxUpdatedAt: null);
    }
  }

  Future<({int failures, String? maxUpdatedAt})> pullItems(String userId) async {
    try {
      final lastPull = AppSettings.instance.lastPullTime;
      final unsynced = await _localDb.getUnsyncedExpenseItems();
      final unsyncedIds = unsynced.map((e) => e.id).toSet();
      String? maxUpdatedAt;

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
        final list = (response as List).map((j) => ExpenseItem.fromJson(j)).toList();
        final rawList = response;

        for (int i = 0; i < list.length; i++) {
          final it = list[i];
          final raw = rawList[i];
          if (raw['updated_at'] != null) {
            maxUpdatedAt = _maxStr(maxUpdatedAt, raw['updated_at'] as String);
          }
          if (unsyncedIds.contains(it.id)) continue;
          await _localDb.upsertExpenseItem(it, skipSync: true);
        }
        if (list.length < pageSize) break;
        offset += pageSize;
      }
      return (failures: 0, maxUpdatedAt: maxUpdatedAt);
    } catch (e) {
      debugPrint('Pull expense items failed: $e');
      return (failures: 1, maxUpdatedAt: null);
    }
  }

  Future<({int failures, String? maxUpdatedAt})> pullExpenses(String userId) async {
    try {
      final lastPull = AppSettings.instance.lastPullTime;
      int offset = 0;
      const pageSize = 500;
      String? maxUpdatedAt;

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
          if (m['updated_at'] != null) {
            maxUpdatedAt = _maxStr(maxUpdatedAt, m['updated_at'] as String);
          }
          
          final id = (m['id'] as num).toInt();
          if (unsyncedIds.contains(id)) continue;
          await _localDb.upsertPulledExpense(Expense.fromJson(m), skipSync: true);
        }
        if (list.length < pageSize) break;
        offset += pageSize;
      }
      return (failures: 0, maxUpdatedAt: maxUpdatedAt);
    } catch (e) {
      debugPrint('Pull expenses failed: $e');
      return (failures: 1, maxUpdatedAt: null);
    }
  }
}