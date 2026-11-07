// lib/services/supabase_service.dart
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
import '../models/open_order.dart';
import '../models/auth_cache.dart';
import '../core/local_db.dart';
import 'sync_runner.dart';
import 'sync_status_service.dart';
import 'app_settings.dart';

part 'supabase_service_data.dart';

enum LoginMode { online, offline }

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
  static bool _isSyncing = false;
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
      await for (var entity in dir.list()) {
        if (entity is File) {
          final filename = entity.path.split('/').last;
          if (filename.startsWith('img_') && filename.endsWith('.jpg')) {
            if (!validPaths.contains(entity.path)) {
              try {
                await entity.delete();
              } catch (e) {
                debugPrint('Failed to delete orphaned image: $e');
              }
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
        throw AuthException(
            'Login gagal. Login pertama kali memerlukan internet.');
      }
      if (!await _hashMatches(password, cache.salt, cache.passwordHash)) {
        throw AuthException('Email atau password salah.');
      }
      if (onlineErr is AuthApiException && onlineErr.statusCode == '400') {
        throw AuthException(
            'Password Anda telah berubah di server. Login online untuk memperbarui.');
      }
      await _saveSecurePassword(password);
      await _setOfflineSession(email);
      return LoginMode.offline;
    }
  }

  Future<void> logout() async {
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

  Future<bool> tryAutoLoginAndSync() async {
    if (!isOfflineSession) return false;
    final email = _cachedOfflineEmail;
    if (email == null) return false;
    try {
      final password = await _secureStorage.read(key: _kSecurePasswordKey);
      if (password == null) return false;
      await _client.auth.signInWithPassword(email: email, password: password);
      await _setOfflineSession(null);
      await syncData();
      return true;
    } catch (e) {
      debugPrint('Auto-login failed (mungkin password berubah di server): $e');
      return false;
    }
  }

  Future<void> syncData() async {
    if (_client.auth.currentSession == null) {
      await SyncStatusService.instance.refreshPendingCount();
      return;
    }
    if (_isSyncing) return;
    _isSyncing = true;
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
    } finally {
      _isSyncing = false;
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