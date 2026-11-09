part of 'sync_runner.dart';

class _SyncClosings {
  final SupabaseClient _client;
  final LocalDb _localDb;

  _SyncClosings(SyncRunner r)
      : _client = r.client,
        _localDb = r.localDb;

  Future<int> sync() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return 0;

    int failures = 0;
    failures += await pushClosings(userId);
    return failures;
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
}