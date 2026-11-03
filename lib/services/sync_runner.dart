// lib/services/sync_runner.dart
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/local_db.dart';
import '../models/product.dart';
import '../models/category.dart';
import '../models/transaction.dart';

part 'sync_runner_push.dart';
part 'sync_runner_pull.dart';

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
    failures += await _SyncPuller(this).pullAll();
    return failures;
  }
}