// lib/services/update_service.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/theme.dart';
import '../models/app_update_info.dart';

/// Service pengecekan update. Prinsip: OFFLINE-FIRST, JANGAN PERNAH
/// memblokir UI. Semua kegagalan (offline, HTTP error, JSON invalid)
/// di-silent; user tetap bisa pakai aplikasi.
///
/// URL manifest dibaca dari --dart-define=UPDATE_MANIFEST_URL.
/// Format JSON:
///   {
///     "latest_version": "1.0.1",
///     "download_url": "https://github.com/USER/REPO/releases/download/v1.0.1/app-release.apk",
///     "release_notes": "Perbaikan bug ...",
///     "force_update": false
///   }
class UpdateService {
  UpdateService._();
  static final UpdateService instance = UpdateService._();

  /// Key navigator global — di-mount ke MaterialApp di main.dart.
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static const String _manifestUrl =
      String.fromEnvironment('UPDATE_MANIFEST_URL');

  static const String _kLastCheckKey = 'natunapos_update_last_check_ms';
  static const Duration _minInterval = Duration(hours: 6);

  bool _isChecking = false;

  /// Entry point. [force] = true melewati throttle (dipakai tombol
  /// "Cek Update" di drawer).
  Future<void> checkAndNotify({bool force = false}) async {
    if (_isChecking) return;
    if (_manifestUrl.isEmpty) {
      debugPrint('Update check skipped: UPDATE_MANIFEST_URL not set.');
      if (force) _showSnack('Fitur update belum dikonfigurasi.');
      return;
    }

    // Throttle (hanya untuk auto-check).
    if (!force) {
      final prefs = await SharedPreferences.getInstance();
      final last = prefs.getInt(_kLastCheckKey) ?? 0;
      final elapsed = DateTime.now().millisecondsSinceEpoch - last;
      if (elapsed < _minInterval.inMilliseconds) {
        debugPrint('Update check throttled.');
        return;
      }
    }

    _isChecking = true;
    if (force) _showSnack('Memeriksa pembaruan...');

    try {
      final info = await _fetchManifest();
      if (info == null) {
        if (force) _showSnack('Gagal memeriksa pembaruan.');
        return;
      }

      // Mark success timestamp HANYA setelah fetch berhasil, agar saat
      // offline retry lebih cepat (tidak menunggu 6 jam).
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
          _kLastCheckKey, DateTime.now().millisecondsSinceEpoch);

      final pkg = await PackageInfo.fromPlatform();
      final current = pkg.version;
      debugPrint('Update: current=$current latest=${info.latestVersion}');

      if (!info.isNewerThan(current)) {
        if (force) _showSnack('Aplikasi sudah versi terbaru ($current).');
        return;
      }
      if (info.downloadUrl.isEmpty) {
        if (force) _showSnack('URL unduhan tidak tersedia.');
        return;
      }

      final ctx = navigatorKey.currentContext;
      if (ctx == null || !ctx.mounted) return;
      await _showUpdateDialog(ctx, info, current);
    } catch (e) {
      // Silent di auto-check; beri feedback hanya saat manual.
      debugPrint('Update check failed (silent): $e');
      if (force) _showSnack('Gagal memeriksa pembaruan.');
    } finally {
      _isChecking = false;
    }
  }

  Future<AppUpdateInfo?> _fetchManifest() async {
    try {
      final uri = Uri.parse(_manifestUrl);
      final resp = await http
          .get(uri, headers: const {'Cache-Control': 'no-cache'})
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode != 200) {
        debugPrint('Manifest HTTP ${resp.statusCode}');
        return null;
      }
      final decoded = jsonDecode(resp.body);
      if (decoded is! Map<String, dynamic>) {
        debugPrint('Manifest: unexpected JSON shape.');
        return null;
      }
      return AppUpdateInfo.fromJson(decoded);
    } catch (e) {
      debugPrint('Fetch manifest failed: $e');
      return null;
    }
  }

  void _showSnack(String message) {
    final ctx = navigatorKey.currentContext;
    if (ctx == null || !ctx.mounted) return;
    ScaffoldMessenger.maybeOf(ctx)?.showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _showUpdateDialog(
    BuildContext context,
    AppUpdateInfo info,
    String currentVersion,
  ) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: !info.forceUpdate,
      builder: (dialogCtx) => PopScope(
        canPop: !info.forceUpdate,
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          title: Row(
            children: const [
              Icon(Icons.system_update, color: AppTheme.primaryColor),
              SizedBox(width: 8),
              Expanded(child: Text('Update Tersedia')),
            ],
          ),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Versi terbaru: ${info.latestVersion}',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text('Versi terpasang: $currentVersion',
                      style: const TextStyle(
                          color: AppTheme.textLightColor, fontSize: 12)),
                  if (info.releaseNotes != null &&
                      info.releaseNotes!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text('Catatan rilis:',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text(info.releaseNotes!,
                        style: const TextStyle(fontSize: 13)),
                  ],
                  if (info.forceUpdate) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.dangerColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Update ini wajib dipasang untuk melanjutkan. '
                        'Aplikasi tidak dapat digunakan sebelum update.',
                        style: TextStyle(
                            color: AppTheme.dangerColor, fontSize: 12),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            if (!info.forceUpdate)
              TextButton(
                onPressed: () => Navigator.of(dialogCtx).pop(),
                child: const Text('NANTI'),
              ),
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.of(dialogCtx).pop();
                await _openUrl(info.downloadUrl);
              },
              icon: const Icon(Icons.download),
              label: const Text('UNDUH'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        debugPrint('Cannot launch URL: $url');
      }
    } catch (e) {
      debugPrint('openUrl failed: $e');
    }
  }
}