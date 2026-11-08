import 'auto_sync_scheduler.dart';
import 'sync_status_service.dart';

class WriteNotifier {
  WriteNotifier._();

  static Future<void> notify() async {
    await SyncStatusService.instance.refreshPendingCount();
    AutoSyncScheduler.instance.scheduleSync();
  }
}