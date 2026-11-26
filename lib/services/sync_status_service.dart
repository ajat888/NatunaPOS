import 'package:flutter/foundation.dart';
import '../core/local_db.dart';

enum SyncState {
  idle,
  syncing,
  pending,
  failed,
}

class SyncStatusService {
  SyncStatusService._();
  static final SyncStatusService instance = SyncStatusService._();

  final ValueNotifier<SyncState> state = ValueNotifier(SyncState.idle);
  final ValueNotifier<int> pendingCount = ValueNotifier(0);
  final ValueNotifier<int> rejectedCount = ValueNotifier(0);
  final ValueNotifier<DateTime?> lastSyncedAt = ValueNotifier(null);

  String? _lastErrorMessage;
  bool _failedNotifiedThisSession = false;

  String? get lastErrorMessage => _lastErrorMessage;

  Future<void> refreshPendingCount() async {
    try {
      final count = await LocalDb.instance.countPendingSync();
      pendingCount.value = count;
      if (state.value != SyncState.syncing &&
          state.value != SyncState.failed) {
        state.value = count > 0 ? SyncState.pending : SyncState.idle;
      }
    } catch (e) {
      debugPrint('refreshPendingCount failed: $e');
    }
    await _refreshRejectedCount();
  }

  Future<void> _refreshPendingCountSilent() async {
    try {
      pendingCount.value = await LocalDb.instance.countPendingSync();
    } catch (e) {
      debugPrint('_refreshPendingCountSilent failed: $e');
    }
    await _refreshRejectedCount();
  }

  Future<void> _refreshRejectedCount() async {
    try {
      final counts = await LocalDb.instance.countRejectedSync();
      rejectedCount.value = counts.values.fold<int>(0, (a, b) => a + b);
    } catch (e) {
      debugPrint('_refreshRejectedCount failed: $e');
    }
  }

  void markSyncing() {
    state.value = SyncState.syncing;
    _lastErrorMessage = null;
  }

  Future<void> markSynced() async {
    lastSyncedAt.value = DateTime.now();
    _lastErrorMessage = null;
    _failedNotifiedThisSession = false;
    state.value = SyncState.idle;
    await refreshPendingCount();
  }

  void markFailed(String message) {
    _lastErrorMessage = message;
    state.value = SyncState.failed;
    _refreshPendingCountSilent();
  }

  bool shouldNotifyFailure() {
    if (_failedNotifiedThisSession) return false;
    _failedNotifiedThisSession = true;
    return true;
  }

  void reset() {
    state.value = SyncState.idle;
    pendingCount.value = 0;
    rejectedCount.value = 0;
    lastSyncedAt.value = null;
    _lastErrorMessage = null;
    _failedNotifiedThisSession = false;
  }
}