import 'dart:async';
import 'package:flutter/foundation.dart';
import 'supabase_service.dart';
import 'sync_status_service.dart';

class AutoSyncScheduler {
  AutoSyncScheduler._();
  static final AutoSyncScheduler instance = AutoSyncScheduler._();

  static const Duration _debounceDelay = Duration(milliseconds: 1500);
  static const Duration _retryInterval = Duration(seconds: 25);
  static const Duration _followUpDelay = Duration(milliseconds: 500);

  Timer? _debounce;
  Timer? _retryTicker;
  bool _started = false;
  bool _inFlight = false;
  bool _queuedAgain = false;
  bool _authFailureNotified = false;

  final ValueNotifier<int> authFailureTick = ValueNotifier<int>(0);

  bool get isStarted => _started;

  void start() {
    if (_started) return;
    _started = true;
    _retryTicker?.cancel();
    _retryTicker = Timer.periodic(_retryInterval, (_) => _tick());
    _tick();
  }

  void stop() {
    _started = false;
    _debounce?.cancel();
    _debounce = null;
    _retryTicker?.cancel();
    _retryTicker = null;
    _inFlight = false;
    _queuedAgain = false;
    _authFailureNotified = false;
  }

  void scheduleSync({Duration? delay}) {
    if (!_started) return;
    _debounce?.cancel();
    _debounce = Timer(delay ?? _debounceDelay, _runSync);
  }

  Future<void> triggerNow() async {
    _debounce?.cancel();
    await _runSync();
  }

  Future<void> _tick() async {
    if (!_started) return;
    if (_inFlight) return;
    final state = SyncStatusService.instance.state.value;
    final pending = SyncStatusService.instance.pendingCount.value;
    if (state == SyncState.idle && pending == 0) return;
    await _runSync();
  }

  Future<void> _runSync() async {
    if (!_started) return;
    if (_inFlight) {
      _queuedAgain = true;
      return;
    }
    _inFlight = true;
    try {
      final service = SupabaseService();
      if (!service.isLoggedIn) return;
      if (service.isOfflineSession) {
        final result = await service.tryAutoLoginAndSync();
        if (result == AutoLoginOutcome.authRejected) {
          _notifyAuthFailureOnce();
        }
        return;
      }
      await service.syncData();
    } catch (e) {
      debugPrint('AutoSyncScheduler run failed: $e');
    } finally {
      _inFlight = false;
      if (_queuedAgain && _started) {
        _queuedAgain = false;
        _debounce?.cancel();
        _debounce = Timer(_followUpDelay, _runSync);
      }
    }
  }

  void _notifyAuthFailureOnce() {
    if (_authFailureNotified) return;
    _authFailureNotified = true;
    authFailureTick.value = authFailureTick.value + 1;
  }
}