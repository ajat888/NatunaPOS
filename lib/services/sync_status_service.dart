// lib/services/sync_status_service.dart
import 'package:flutter/foundation.dart';
import '../core/local_db.dart';

/// Status sinkronisasi global. Dipakai oleh UI (indikator) dan
/// oleh SupabaseService (update saat sync berjalan).
enum SyncState {
  /// Tidak ada antrian, tidak sedang sync.
  idle,
  /// Sedang sync.
  syncing,
  /// Ada antrian belum tersinkron.
  pending,
  /// Sync terakhir gagal.
  failed,
}

class SyncStatusService {
  SyncStatusService._();
  static final SyncStatusService instance = SyncStatusService._();

  final ValueNotifier<SyncState> state = ValueNotifier(SyncState.idle);
  final ValueNotifier<int> pendingCount = ValueNotifier(0);
  final ValueNotifier<DateTime?> lastSyncedAt = ValueNotifier(null);

  String? _lastErrorMessage;
  bool _failedNotifiedThisSession = false;

  String? get lastErrorMessage => _lastErrorMessage;

  /// Query pending count dan update state — kecuali sedang syncing / failed
  /// (agar status tersebut tidak tertimpa).
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
  }

  /// Query pending count tanpa mengubah state (dipakai saat failed).
  Future<void> _refreshPendingCountSilent() async {
    try {
      pendingCount.value = await LocalDb.instance.countPendingSync();
    } catch (e) {
      debugPrint('_refreshPendingCountSilent failed: $e');
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
    // Set idle dulu agar refreshPendingCount bisa override ke pending
    // jika ternyata masih ada antrian (mis. data baru masuk saat sync).
    state.value = SyncState.idle;
    await refreshPendingCount();
  }

  void markFailed(String message) {
    _lastErrorMessage = message;
    state.value = SyncState.failed;
    _refreshPendingCountSilent();
  }

  /// True jika SnackBar gagal perlu ditampilkan (sekali per sesi gagal).
  bool shouldNotifyFailure() {
    if (_failedNotifiedThisSession) return false;
    _failedNotifiedThisSession = true;
    return true;
  }

  /// Reset total saat logout.
  void reset() {
    state.value = SyncState.idle;
    pendingCount.value = 0;
    lastSyncedAt.value = null;
    _lastErrorMessage = null;
    _failedNotifiedThisSession = false;
  }
}