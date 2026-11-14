import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PinStatus {
  final bool hasPin;
  final int lockedUntilMs;
  const PinStatus({required this.hasPin, required this.lockedUntilMs});
}

class PinVerifyResult {
  final bool valid;
  final int lockedUntilMs;
  final int failedAttempts;
  const PinVerifyResult({
    required this.valid,
    required this.lockedUntilMs,
    required this.failedAttempts,
  });
}

class PinService {
  PinService._();
  static final PinService instance = PinService._();

  static const String _envApiUrl = String.fromEnvironment('API_BASE_URL');
  static const String _kActivePin = 'natunapos_active_pin';
  static const String _kLastVerifiedAtMs = 'natunapos_last_verified_at_ms';
  static const int _validDurationMs = 15 * 60 * 1000; // 15 Menit

  String get _apiBase {
    if (_envApiUrl.isNotEmpty) return _envApiUrl;
    if (kIsWeb) return Uri.base.origin;
    return '';
  }

  String? get _jwt => Supabase.instance.client.auth.currentSession?.accessToken;

  Future<bool> checkUnlocked() async {
    final prefs = await SharedPreferences.getInstance();
    final pin = prefs.getString(_kActivePin);
    final lastVerified = prefs.getInt(_kLastVerifiedAtMs) ?? 0;

    if (pin == null || pin.isEmpty) return false;

    final elapsed = DateTime.now().millisecondsSinceEpoch - lastVerified;
    if (elapsed >= _validDurationMs) {
      await prefs.remove(_kActivePin);
      await prefs.remove(_kLastVerifiedAtMs);
      return false;
    }
    return true;
  }

  Future<String?> getActivePin() async {
    if (await checkUnlocked()) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_kActivePin);
    }
    return null;
  }

  Future<void> lock() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kActivePin);
    await prefs.remove(_kLastVerifiedAtMs);
  }

  Future<Map<String, dynamic>> _post(
    Map<String, dynamic> body, {
    bool auth = true,
  }) async {
    if (_apiBase.isEmpty) {
      throw Exception('API_BASE_URL belum dikonfigurasi. Hubungi developer.');
    }
    final url = '$_apiBase/api/pin';
    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (auth && _jwt != null) 'Authorization': 'Bearer $_jwt',
    };

    http.Response resp;
    try {
      resp = await http
          .post(Uri.parse(url), headers: headers, body: jsonEncode(body))
          .timeout(const Duration(seconds: 20));
    } on TimeoutException {
      throw Exception('Waktu habis. Periksa koneksi internet.');
    } on http.ClientException catch (e) {
      throw Exception('Tidak dapat terhubung ke server: ${e.message}');
    }

    Map<String, dynamic> decoded;
    try {
      decoded = jsonDecode(resp.body) as Map<String, dynamic>;
    } catch (_) {
      throw Exception('Respons server tidak valid (HTTP ${resp.statusCode})');
    }

    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      return decoded;
    }
    throw Exception(
        (decoded['error'] as String?) ?? 'Gagal (HTTP ${resp.statusCode})');
  }

  Future<PinStatus> getStatus() async {
    final res = await _post({'action': 'status'});
    return PinStatus(
      hasPin: res['has_pin'] as bool? ?? false,
      lockedUntilMs: (res['locked_until_ms'] as num?)?.toInt() ?? 0,
    );
  }

  Future<void> setPin(String pin) async {
    await _post({'action': 'set', 'pin': pin});
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kActivePin, pin);
    await prefs.setInt(_kLastVerifiedAtMs, DateTime.now().millisecondsSinceEpoch);
  }

  Future<PinVerifyResult> verifyPin(String pin) async {
    final res = await _post({'action': 'verify', 'pin': pin});
    final result = PinVerifyResult(
      valid: res['valid'] as bool? ?? false,
      lockedUntilMs: (res['locked_until_ms'] as num?)?.toInt() ?? 0,
      failedAttempts: (res['failed_attempts'] as num?)?.toInt() ?? 0,
    );
    if (result.valid) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kActivePin, pin);
      await prefs.setInt(_kLastVerifiedAtMs, DateTime.now().millisecondsSinceEpoch);
    }
    return result;
  }

  Future<void> resetPin({
    required String email,
    required String password,
  }) async {
    await _post(
      {'action': 'reset', 'email': email, 'password': password},
      auth: false,
    );
    await lock();
  }
}