part of '../settings_screen.dart';

class _AboutSection extends StatefulWidget {
  const _AboutSection();

  @override
  State<_AboutSection> createState() => _AboutSectionState();
}

class _AboutSectionState extends State<_AboutSection> {
  String _version = '—';
  bool _busySync = false;
  bool _busyUpdate = false;
  bool _busyCache = false;
  
  Timer? _ticker;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadVersion();
    _startTicker();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _startTicker() {
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _now = DateTime.now();
        });
      }
    });
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() {
        _version = '${info.version}+${info.buildNumber}';
      });
    } catch (e) {
      debugPrint('Load version failed: $e');
      if (!mounted) return;
      setState(() => _version = '—');
    }
  }

  Future<void> _syncNow() async {
    setState(() => _busySync = true);
    try {
      await SupabaseService().syncData();
      if (!mounted) return;
      final pending = SyncStatusService.instance.pendingCount.value;
      final failed =
          SyncStatusService.instance.state.value == SyncState.failed;
      final msg = failed
          ? 'Sinkronisasi gagal. Coba lagi nanti.'
          : pending > 0
              ? 'Tersisa $pending perubahan menunggu.'
              : 'Sinkronisasi selesai.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: failed ? AppTheme.dangerColor : Colors.green,
        ),
      );
    } catch (e) {
      debugPrint('Manual sync failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sinkronisasi gagal.'),
          backgroundColor: AppTheme.dangerColor,
        ),
      );
    } finally {
      if (mounted) setState(() => _busySync = false);
    }
  }

  Future<void> _checkUpdate() async {
    setState(() => _busyUpdate = true);
    try {
      await UpdateService.instance.checkAndNotify(force: true);
    } catch (e) {
      debugPrint('Manual update check failed: $e');
    } finally {
      if (mounted) setState(() => _busyUpdate = false);
    }
  }

  Future<void> _clearCache() async {
    setState(() => _busyCache = true);
    try {
      await SupabaseService().clearTempCache();
      await SupabaseService().cleanupOrphanedImages();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cache dibersihkan'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      debugPrint('Clear cache failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gagal membersihkan cache'),
          backgroundColor: AppTheme.dangerColor,
        ),
      );
    } finally {
      if (mounted) setState(() => _busyCache = false);
    }
  }

  String _formatRelativeTime(DateTime? date) {
    if (date == null) return 'Belum pernah';
    
    final diff = _now.difference(date);
    
    if (diff.inSeconds < 0) return 'Baru saja';
    if (diff.inSeconds < 60) {
      return '${diff.inSeconds} detik yang lalu';
    }
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes} menit yang lalu';
    }
    if (diff.inHours < 24) {
      return '${diff.inHours} jam yang lalu';
    }
    if (diff.inDays < 30) {
      return '${diff.inDays} hari yang lalu';
    }
    
    final dd = date.day.toString().padLeft(2, '0');
    final mm = date.month.toString().padLeft(2, '0');
    final hh = date.hour.toString().padLeft(2, '0');
    final mi = date.minute.toString().padLeft(2, '0');
    return '$dd/$mm/${date.year} $hh:$mi';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionHeader('Tentang Aplikasi'),
        _card(
          child: Column(
            children: [
              _infoTile('Versi Aplikasi', _version),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              ValueListenableBuilder<DateTime?>(
                valueListenable: SyncStatusService.instance.lastSyncedAt,
                builder: (context, last, _) {
                  return _infoTile('Sinkron Terakhir', _formatRelativeTime(last));
                },
              ),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              ValueListenableBuilder<int>(
                valueListenable: SyncStatusService.instance.pendingCount,
                builder: (context, pending, _) {
                  return _infoTile('Menunggu Sinkron', '$pending perubahan');
                },
              ),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              _actionTile(
                icon: Icons.sync,
                label: 'Sinkron Sekarang',
                busy: _busySync,
                onTap: _syncNow,
              ),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              _actionTile(
                icon: Icons.system_update,
                label: 'Cek Update',
                busy: _busyUpdate,
                onTap: _checkUpdate,
              ),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              _actionTile(
                icon: Icons.cleaning_services_outlined,
                label: 'Bersihkan Cache',
                busy: _busyCache,
                onTap: _clearCache,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _infoTile(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textLightColor,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionTile({
    required IconData icon,
    required String label,
    required bool busy,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: busy ? null : onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppTheme.primaryColor),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textColor,
                ),
              ),
            ),
            if (busy)
              const SizedBox(
                height: 16,
                width: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              const Icon(
                Icons.chevron_right,
                size: 18,
                color: AppTheme.textLightColor,
              ),
          ],
        ),
      ),
    );
  }
}