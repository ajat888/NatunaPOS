import '../core/file_utils.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show debugPrint, compute;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/product.dart';
import '../models/category.dart';
import '../models/transaction.dart';
import '../models/auth_cache.dart';
import '../models/voided_open_order.dart';
import '../core/local_db.dart';
import 'auto_sync_scheduler.dart';
import 'sync_runner.dart';
import 'sync_status_service.dart';
import 'app_settings.dart';
import 'pin_service.dart';

part 'supabase_service_data.dart';

class PendingSyncException implements Exception {
  final int pendingCount;
  const PendingSyncException(this.pendingCount);
  @override
  String toString() => 'Masih ada $pendingCount perubahan belum tersinkron.';
}

enum LoginMode { online, offline }

enum AutoLoginOutcome {
  success,
  notApplicable,
  missingCredentials,
  authRejected,
  offlineError,
}

String _computePasswordHash(Map<String, String> args) {
  final password = args['password'] ?? '';
  final salt = args['salt'] ?? '';
  final initial = utf8.encode('$salt$password$salt');
  var digest = sha256.convert(initial);
  for (var i = 0; i < 10000; i++) {
    digest = sha256.convert([...digest.bytes, ...utf8.encode(salt)]);
  }
  return digest.toString();
}

class SupabaseService {
  SupabaseService._();
  static final SupabaseService _instance = SupabaseService._();
  factory SupabaseService() => _instance;

  SupabaseClient get _client => Supabase.instance.client;
  final LocalDb _localDb = LocalDb.instance;
  static Future<void>? _activeSync;
  static final Random _rng = Random();

  final _secureStorage = const FlutterSecureStorage();
  static const String _kSecurePasswordKey = 'natunapos_secure_password';
  static const String _kOfflineEmailKey = 'offline_session_email';
  String? _cachedOfflineEmail;

  Future<void> initSession() async {
    final prefs = await SharedPreferences.getInstance();
    _cachedOfflineEmail = prefs.getString(_kOfflineEmailKey);
    if (_client.auth.currentSession != null && _cachedOfflineEmail != null) {
      _cachedOfflineEmail = null;
      await prefs.remove(_kOfflineEmailKey);
    }
  }

  Future<void> cleanupOrphanedImages() async {
  try {
    final paths = await _localDb.getAllLocalImagePaths();
    final dir = await getApplicationDocumentsDirectory();
    if (!await dir.exists()) return;
    final validPaths = paths.toSet();
    final now = DateTime.now();
    await for (var entity in dir.list()) {
      if (entity is File) {
        final filename = entity.path.split('/').last;
        if (filename.startsWith('img_') && filename.endsWith('.jpg')) {
  try {
    final stat = await entity.stat();
    final keep = FileUtils.shouldKeepOrphanedFile(
      now: now,
      fileModified: stat.modified,
      isValidPath: validPaths.contains(entity.path),
    );
    if (keep) continue;
    await entity.delete();
  } catch (e) {
    debugPrint('Failed to delete orphaned image: $e');
  }
}
      }
    }
  } catch (e) {
    debugPrint('cleanupOrphanedImages error: $e');
  }
}

  Future<void> clearTempCache() async {
    try {
      final dir = await getTemporaryDirectory();
      if (!await dir.exists()) return;
      await for (var entity in dir.list()) {
        try {
          await entity.delete(recursive: true);
        } catch (e) {
          debugPrint('Failed to delete temp entity: $e');
        }
      }
    } catch (e) {
      debugPrint('clearTempCache error: $e');
    }
  }

  Future<LoginMode> login(String email, String password) async {
    try {
      await _client.auth.signInWithPassword(email: email, password: password);
      await _saveAuthCache(email, password);
      await _saveSecurePassword(password);
      await _setOfflineSession(null);
      return LoginMode.online;
    } catch (onlineErr) {
      final cache = await _localDb.getAuthCache(email);
      if (cache == null) {
  if (onlineErr is AuthException) rethrow;
  throw const AuthException(
      'Login gagal. Login pertama kali memerlukan internet.');
}
if (!await _hashMatches(password, cache.salt, cache.passwordHash)) {
  throw const AuthException('Email atau password salah.');
}
if (onlineErr is AuthApiException && onlineErr.statusCode == '400') {
  throw const AuthException(
      'Password Anda telah berubah di server. Login online untuk memperbarui.');
}
      await _saveSecurePassword(password);
      await _setOfflineSession(email);
      return LoginMode.offline;
    }
  }

  Future<void> logout({bool force = false}) async {
  AutoSyncScheduler.instance.stop();
  await PinService.instance.lock();

    if (!force) {
      if (_client.auth.currentSession != null) {
      try {
        await syncData();
      } catch (e) {
        debugPrint('Pre-logout sync failed: $e');
      }
    }
    final pending = await _localDb.countPendingSync();
    if (pending > 0) {
      AutoSyncScheduler.instance.start();
      throw PendingSyncException(pending);
    }
  }

  await _setOfflineSession(null);
  await _deleteSecurePassword();
  SyncStatusService.instance.reset();
  await _localDb.clearAllData();
  try {
    await _client.auth.signOut();
  } catch (e) {
    debugPrint('Logout global failed (likely offline): $e');
    try {
      await _client.auth.signOut(scope: SignOutScope.local);
    } catch (e2) {
      debugPrint('Local signout also failed: $e2');
    }
  }
}

  bool get isLoggedIn =>
      _client.auth.currentSession != null || _cachedOfflineEmail != null;

  bool get isOfflineSession =>
      _client.auth.currentSession == null && _cachedOfflineEmail != null;

  Future<void> _setOfflineSession(String? email) async {
    final prefs = await SharedPreferences.getInstance();
    _cachedOfflineEmail = email;
    if (email == null) {
      await prefs.remove(_kOfflineEmailKey);
    } else {
      await prefs.setString(_kOfflineEmailKey, email);
    }
  }

  Future<void> _saveSecurePassword(String password) async {
    try {
      await _secureStorage.write(key: _kSecurePasswordKey, value: password);
    } catch (e) {
      debugPrint('Failed to save secure password: $e');
    }
  }

  Future<void> _deleteSecurePassword() async {
    try {
      await _secureStorage.delete(key: _kSecurePasswordKey);
    } catch (e) {
      debugPrint('Failed to delete secure password: $e');
    }
  }

  Future<AutoLoginOutcome> tryAutoLoginAndSync() async {
    if (!isOfflineSession) {
      if (_client.auth.currentSession != null) {
        await syncData();
        return AutoLoginOutcome.success;
      }
      return AutoLoginOutcome.notApplicable;
    }
    final email = _cachedOfflineEmail;
    if (email == null) return AutoLoginOutcome.notApplicable;
    final password = await _secureStorage.read(key: _kSecurePasswordKey);
    if (password == null) return AutoLoginOutcome.missingCredentials;
    try {
      await _client.auth.signInWithPassword(email: email, password: password);
      await _setOfflineSession(null);
      await syncData();
      return AutoLoginOutcome.success;
    } on AuthException catch (e) {
      final msg = e.message.toLowerCase();
      final isNetwork = msg.contains('network') ||
          msg.contains('connection') ||
          msg.contains('socket') ||
          msg.contains('timeout') ||
          msg.contains('host lookup') ||
          msg.contains('failed');
      if (isNetwork) return AutoLoginOutcome.offlineError;
      return AutoLoginOutcome.authRejected;
    } catch (e) {
      debugPrint('Auto-login failed: $e');
      return AutoLoginOutcome.offlineError;
    }
  }

  Future<void> syncData() async {
  if (_client.auth.currentSession == null) {
    await SyncStatusService.instance.refreshPendingCount();
    if (SyncStatusService.instance.pendingCount.value > 0) {
      SyncStatusService.instance.markFailed(
          'Sesi tidak aktif. Silakan login untuk sinkronisasi.');
    }
    return;
  }
  final existing = _activeSync;
  if (existing != null) {
    await existing;
    return;
  }
  final run = _performSync();
  _activeSync = run;
  try {
    await run;
  } finally {
    if (identical(_activeSync, run)) {
      _activeSync = null;
    }
  }
}

Future<void> _performSync() async {
  SyncStatusService.instance.markSyncing();
  try {
    final failures = await SyncRunner(
      client: _client,
      localDb: _localDb,
      rng: _rng,
    ).run();
    if (failures > 0) {
      SyncStatusService.instance.markFailed(
          'Sinkronisasi gagal ($failures operasi). Akan dicoba lagi otomatis.');
    } else {
      await SyncStatusService.instance.markSynced();
    }
  } catch (e) {
    debugPrint('syncData unexpected error: $e');
    SyncStatusService.instance
        .markFailed('Sinkronisasi gagal: ${e.toString()}');
  }
}

  Future<void> _saveAuthCache(String email, String password) async {
    final salt = _generateSalt();
    final hash = await _hashPassword(password, salt);
    await _localDb.upsertAuthCache(AuthCacheEntry(
      email: email,
      passwordHash: hash,
      salt: salt,
      lastOnlineLoginMs: DateTime.now().millisecondsSinceEpoch,
    ));
  }

  String _generateSalt() {
    final rng = Random.secure();
    return base64Encode(List.generate(16, (_) => rng.nextInt(256)));
  }

  Future<String> _hashPassword(String password, String salt) {
    return compute(_computePasswordHash, {
      'password': password,
      'salt': salt,
    });
  }

  Future<bool> _hashMatches(
      String password, String salt, String expectedHash) async {
    final computed = await _hashPassword(password, salt);
    return computed == expectedHash;
  }
}