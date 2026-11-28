import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/local_db.dart';
import '../core/tax_settings.dart';
import '../core/fixed_cost_settings.dart';
import '../models/product.dart';
import '../models/category.dart';
import '../models/transaction.dart';
import '../models/open_order.dart';
import '../models/expense_category.dart';
import '../models/expense_item.dart';
import '../models/expense.dart';
import '../models/daily_closing.dart';
import 'app_settings.dart';

part 'sync_runner_push.dart';
part 'sync_runner_pull.dart';
part 'sync_runner_open_orders.dart';
part 'sync_runner_settings.dart';
part 'sync_runner_expenses_push.dart';
part 'sync_runner_expenses_pull.dart';
part 'sync_runner_closings.dart';
part 'sync_runner_voids.dart';

class SyncRunner {
  final SupabaseClient client;
  final LocalDb localDb;
  final Random rng;

  SyncRunner({
    required this.client,
    required this.localDb,
    Random? rng,
  }) : rng = rng ?? Random();

Future<int> run() async {
  int failures = 0;

  final openOrderSync = _SyncOpenOrder(this);
  if (!kIsWeb) {
    final pushRes = await _SyncPusher(this).pushAll();
    failures += pushRes.blocking;

    failures += await openOrderSync.pushDeletes();
    failures += await openOrderSync.pushUpserts();

    failures += await _SyncExpensesPusher(this).pushAll();
  }

  if (failures > 0) return failures;

  int pullFailures = 0;

  final pullRes = await _SyncPuller(this).pullAll();
  pullFailures += pullRes.failures;

  final openPullRes = await openOrderSync.pull();
  pullFailures += openPullRes.failures;

  final expPullRes = await _SyncExpensesPuller(this).pullAll();
  pullFailures += expPullRes.failures;

  final closingRes = await _SyncClosings(this).sync();
  pullFailures += closingRes.failures;

  final settingsFailures = await _SyncSettings(this).sync();
  pullFailures += settingsFailures;

  if (pullFailures == 0) {
    String? maxUpdatedAt = pullRes.maxUpdatedAt;
    
    if (openPullRes.maxUpdatedAt != null) {
      if (maxUpdatedAt == null || openPullRes.maxUpdatedAt!.compareTo(maxUpdatedAt) > 0) {
        maxUpdatedAt = openPullRes.maxUpdatedAt;
      }
    }
    if (expPullRes.maxUpdatedAt != null) {
      if (maxUpdatedAt == null || expPullRes.maxUpdatedAt!.compareTo(maxUpdatedAt) > 0) {
        maxUpdatedAt = expPullRes.maxUpdatedAt;
      }
    }
    if (closingRes.maxUpdatedAt != null) {
      if (maxUpdatedAt == null || closingRes.maxUpdatedAt!.compareTo(maxUpdatedAt) > 0) {
        maxUpdatedAt = closingRes.maxUpdatedAt;
      }
    }

    if (maxUpdatedAt != null) {
      await AppSettings.instance.setLastPullTime(maxUpdatedAt);
    }
  }

  return pullFailures;
}
}