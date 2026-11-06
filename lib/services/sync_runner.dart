import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/local_db.dart';
import '../core/tax_settings.dart';
import '../models/product.dart';
import '../models/category.dart';
import '../models/transaction.dart';
import '../models/open_order.dart';
import 'app_settings.dart';

part 'sync_runner_push.dart';
part 'sync_runner_pull.dart';
part 'sync_runner_open_orders.dart';
part 'sync_runner_settings.dart';

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
    failures += await _SyncPusher(this).pushAll();

    final openOrderSync = _SyncOpenOrder(this);
    failures += await openOrderSync.pushDeletes();
    failures += await openOrderSync.pushUpserts();

    failures += await _SyncPuller(this).pullAll();
    failures += await openOrderSync.pull();
    failures += await _SyncSettings(this).sync();

    return failures;
  }
}