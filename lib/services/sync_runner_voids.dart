part of 'sync_runner.dart';

Future<({int failures, int rejected})> _pushVoidedTransactions({
  required SupabaseClient client,
  required LocalDb localDb,
  required bool Function(Object) isPermanentRejection,
}) async {
  int failures = 0;
  int rejected = 0;
  final unsynced = await localDb.getUnsyncedVoidedTransactions();
  for (final tx in unsynced) {
    if (tx.id < 0) continue;
    try {
      await client.from('transactions').update({
        'is_voided': true,
        'void_reason': tx.voidReason,
        'voided_by': tx.voidedBy,
        'voided_at':
            (tx.voidedAt ?? DateTime.now()).toUtc().toIso8601String(),
      }).eq('id', tx.id);
      await localDb.markTransactionVoidSynced(tx.id, skipSync: true);
    } catch (e) {
      debugPrint('Push void tx ${tx.id} failed: $e');
      if (isPermanentRejection(e)) {
        rejected++;
        await localDb.markTransactionRejected(tx.id, skipSync: true);
      } else {
        failures++;
      }
    }
  }
  return (failures: failures, rejected: rejected);
}
