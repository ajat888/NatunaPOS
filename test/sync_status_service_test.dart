import 'package:flutter_test/flutter_test.dart';
import 'package:natunapos/services/sync_status_service.dart';

void main() {
  group('SyncStatusService', () {
    late SyncStatusService service;

    setUp(() {
      service = SyncStatusService.instance;
      service.reset();
    });

    test('Initial state should be idle and pending count 0', () {
      expect(service.state.value, SyncState.idle);
      expect(service.pendingCount.value, 0);
      expect(service.lastSyncedAt.value, isNull);
    });

    test('markSyncing should change state to syncing', () {
      service.markSyncing();
      expect(service.state.value, SyncState.syncing);
      expect(service.lastErrorMessage, isNull);
    });

    test('markFailed should change state to failed and set error message', () {
      service.markFailed('Network error');
      expect(service.state.value, SyncState.failed);
      expect(service.lastErrorMessage, 'Network error');
    });

    test('shouldNotifyFailure should only return true once', () {
      service.markFailed('Error 1');
      expect(service.shouldNotifyFailure(), isTrue);
      
      // Panggilan kedua dalam siklus gagal yang sama harus false
      expect(service.shouldNotifyFailure(), isFalse);
    });

    test('reset should clear all states and values', () {
      service.markFailed('Error');
      service.pendingCount.value = 10;
      service.lastSyncedAt.value = DateTime.now();
      
      service.reset();
      
      expect(service.state.value, SyncState.idle);
      expect(service.pendingCount.value, 0);
      expect(service.lastSyncedAt.value, isNull);
      expect(service.lastErrorMessage, isNull);
    });
  });
}