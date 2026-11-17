part of 'sync_runner.dart';

class _SyncClosings {
  final SupabaseClient _client;
  final LocalDb _localDb;

  _SyncClosings(SyncRunner r)
      : _client = r.client,
        _localDb = r.localDb;

  Future<({int failures, String? maxUpdatedAt})> sync() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return (failures: 0, maxUpdatedAt: null);

    int failures = 0;
    String? maxUpdatedAt;

    final pushRes = await pushClosings(userId);
    failures += pushRes;
    if (failures > 0) return (failures: failures, maxUpdatedAt: null);

    final pullRes = await pullClosings(userId);
    failures += pullRes.failures;
    maxUpdatedAt = pullRes.maxUpdatedAt;

    return (failures: failures, maxUpdatedAt: maxUpdatedAt);
  }

  Future<int> pushClosings(String userId) async {
    int failures = 0;
    final unsynced = await _localDb.getUnsyncedClosings();
    for (final c in unsynced) {
      try {
        await _client.from('daily_closings').upsert({
          'user_id': userId,
          'closing_date': c.closingDate,
          'total_sales': c.totalSales,
          'total_transactions': c.totalTransactions,
          'total_hpp': c.totalHpp,
          'total_expenses': c.totalExpenses,
          'total_void_amount': c.totalVoidAmount,
          'void_count': c.voidCount,
          'cash_expected': c.cashExpected,
          'cash_actual': c.cashActual,
          'cash_difference': c.cashDifference,
          'closing_note': c.closingNote,
          'closed_by': c.closedBy,
          'closed_at': c.closedAt.toUtc().millisecondsSinceEpoch,
        }, onConflict: 'user_id,closing_date');
        
        await _localDb.markClosingSynced(c.id, skipSync: true);
      } catch (e) {
        debugPrint('Push closing ${c.closingDate} failed: $e');
        failures++;
      }
    }
    return failures;
  }

  Future<({int failures, String? maxUpdatedAt})> pullClosings(String userId) async {
    try {
      final lastPull = AppSettings.instance.lastPullTime;
      final response = await _client
          .from('daily_closings')
          .select()
          .eq('user_id', userId)
          .gt('updated_at', lastPull)
          .order('updated_at', ascending: true);

      String? maxUpdatedAt;
      for (final raw in (response as List)) {
        final m = raw as Map<String, dynamic>;
        if (m['updated_at'] != null) {
          final u = m['updated_at'] as String;
          if (maxUpdatedAt == null || u.compareTo(maxUpdatedAt) > 0) {
            maxUpdatedAt = u;
          }
        }
        
        final closing = DailyClosing.fromJson(m);
        final existing = await _localDb.getDailyClosingByDate(closing.closingDate);
        if (existing != null && !existing.isSynced) {
          continue;
        }
        
        await _localDb.upsertPulledClosing(closing, skipSync: true);
      }
      return (failures: 0, maxUpdatedAt: maxUpdatedAt);
    } catch (e) {
      debugPrint('Pull closings failed: $e');
      return (failures: 1, maxUpdatedAt: null);
    }
  }
}