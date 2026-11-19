import 'dart:async';
import 'package:flutter/foundation.dart';
import 'supabase_service.dart';
import 'sync_status_service.dart';

class AutoSyncScheduler {
  AutoSyncScheduler._();
  static final AutoSyncScheduler instance = AutoSyncScheduler._();

  static const Duration _debounceDelay = Duration(milliseconds: 1500);
  static const Duration _followUpDelay = Duration(milliseconds: 500);
  static const Duration _baseRetryInterval = Duration(seconds: 25);
  static const Duration _maxRetryInterval = Duration(minutes: 10);
  static const int _maxRetryAttempts = 5;

  Timer? _debounce;
  Timer? _retryTimer;
  int _retryAttempt = 0;

  bool _started = false;
  bool _inFlight = false;
  String get debugState =>
      'started=$_started inFlight=$_inFlight queued=$_queuedAgain';
  bool _queuedAgain = false;
  bool _authFailureNotified = false;

  final ValueNotifier<int> authFailureTick = ValueNotifier<int>(0);

  bool get isStarted => _started;

  void start() {
    if (_started) return;
    _started = true;
    _scheduleNextRetry();
    _tick();
  }

  void stop() {
    _started = false;
    _debounce?.cancel();
    _debounce = null;
    _retryTimer?.cancel();
    _retryTimer = null;
    _retryAttempt = 0;
    _inFlight = false;
    _queuedAgain = false;
    _authFailureNotified = false;
  }

  void scheduleSync({Duration? delay}) {
    if (!_started) return;
    _debounce?.cancel();
    _retryTimer?.cancel();
    _retryAttempt = 0;
    _debounce = Timer(delay ?? _debounceDelay, _runSync);
  }

  Future<void> triggerNow() async {
    _debounce?.cancel();
    await _runSync();
  }

  void _scheduleNextRetry() {
  if (!_started) return;
  _retryTimer?.cancel();

  if (_retryAttempt >= _maxRetryAttempts) {
    debugPrint('AutoSyncScheduler: Batas maksimal retry ($_maxRetryAttempts) tercapai. Jeda ${_maxRetryInterval.inMinutes} menit.');
    SyncStatusService.instance.markFailed(
        'Sinkronisasi gagal berulang kali. Silakan periksa koneksi atau login ulang.');
    _retryTimer = Timer(_maxRetryInterval, () {
      _retryAttempt = 0;
      unawaited(_tick());
    });
    return;
  }
  
  final multiplier = 1 << (_retryAttempt > 5 ? 5 : _retryAttempt);
  var delay = _baseRetryInterval * multiplier;
  if (delay > _maxRetryInterval) {
    delay = _maxRetryInterval;
  }

  _retryTimer = Timer(delay, () => _tick());
}

  Future<void> _tick() async {
  if (!_started) return;
  if (_inFlight) return;
  if (_retryAttempt >= _maxRetryAttempts) return;

  final state = SyncStatusService.instance.state.value;
  final pending = SyncStatusService.instance.pendingCount.value;
  
  if (state == SyncState.idle && pending == 0) {
    _retryAttempt = 0;
    _scheduleNextRetry();
    return;
  }
  await _runSync();
}

  Future<void> _runSync() async {
    if (!_started) {
      SyncStatusService.instance.markFailed('Scheduler belum aktif (started=false)');
      return;
    }
    if (_inFlight) {
      _queuedAgain = true;
      return;
    }
    _inFlight = true;
    bool stopRetry = false;

    try {
      final service = SupabaseService();
      if (!service.isLoggedIn) return;

      if (service.isOfflineSession) {
        final result = await service.tryAutoLoginAndSync();
        if (result == AutoLoginOutcome.authRejected ||
            result == AutoLoginOutcome.missingCredentials) {
          _notifyAuthFailureOnce();
          SyncStatusService.instance.markFailed(
              'Sesi offline tidak dapat dipulihkan. Silakan login ulang.');
          stopRetry = true;
          return;
        }
        if (result == AutoLoginOutcome.offlineError) {
          SyncStatusService.instance.markFailed('Tidak dapat terhubung ke server.');
          _retryAttempt++;
          return;
        }
        if (result == AutoLoginOutcome.notApplicable) {
          SyncStatusService.instance.markFailed('Sesi tidak valid. Silakan login ulang.');
          stopRetry = true;
          return;
        }
      }

      await service.syncData();
      if (SyncStatusService.instance.state.value == SyncState.failed) {
        _retryAttempt++;
      } else {
        _retryAttempt = 0;
      }
    } catch (e) {
      debugPrint('AutoSyncScheduler run failed: $e');
      SyncStatusService.instance
          .markFailed('Sinkronisasi gagal: ${e.toString()}');
      _retryAttempt++;
    } finally {
      _inFlight = false;
      if (stopRetry) {
        _retryTimer?.cancel();
        _retryTimer = null;
      } else if (_queuedAgain && _started) {
        _queuedAgain = false;
        _debounce?.cancel();
        _debounce = Timer(_followUpDelay, _runSync);
      } else {
        _scheduleNextRetry();
      }
    }
  }

  void _notifyAuthFailureOnce() {
    if (_authFailureNotified) return;
    _authFailureNotified = true;
    authFailureTick.value = authFailureTick.value + 1;
  }
}