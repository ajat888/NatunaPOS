// lib/models/app_update_info.dart

/// Representasi satu entri manifest update dari server.
class AppUpdateInfo {
  final String latestVersion;
  final String downloadUrl;
  final String? releaseNotes;
  final bool forceUpdate;

  const AppUpdateInfo({
    required this.latestVersion,
    required this.downloadUrl,
    this.releaseNotes,
    this.forceUpdate = false,
  });

  factory AppUpdateInfo.fromJson(Map<String, dynamic> json) {
    return AppUpdateInfo(
      latestVersion: (json['latest_version'] as String?)?.trim() ?? '',
      downloadUrl: (json['download_url'] as String?)?.trim() ?? '',
      releaseNotes: (json['release_notes'] as String?)?.trim(),
      forceUpdate: json['force_update'] as bool? ?? false,
    );
  }

  /// True jika [currentVersion] lebih lama dari [latestVersion].
  /// Mendukung format "1.2.3" dan "1.2.3+4" (build number di-strip).
  bool isNewerThan(String currentVersion) {
    return _compare(currentVersion, latestVersion) < 0;
  }

  static int _compare(String a, String b) {
    final pa = _parse(a);
    final pb = _parse(b);
    final maxLen = pa.length > pb.length ? pa.length : pb.length;
    for (var i = 0; i < maxLen; i++) {
      final va = i < pa.length ? pa[i] : 0;
      final vb = i < pb.length ? pb[i] : 0;
      if (va != vb) return va.compareTo(vb);
    }
    return 0;
  }

  static List<int> _parse(String v) {
    final base = v.split('+').first;
    return base.split('.').map((s) => int.tryParse(s.trim()) ?? 0).toList();
  }
}