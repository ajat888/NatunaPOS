import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../core/theme.dart';
import 'dashboard_screen.dart';
import 'pos_screen.dart';
import 'kelola_screen.dart';
import 'history_screen.dart';
import 'expenses_screen.dart';
import 'login_screen.dart';
import 'settings_screen.dart';
import 'reports_screen.dart';
import 'closing_screen.dart';
import '../services/auto_sync_scheduler.dart';
import '../services/update_service.dart';
import '../services/supabase_service.dart';
import '../services/sync_status_service.dart';
import '../widgets/common/main_menu_scope.dart';

part 'main_layout_drawer.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> with WidgetsBindingObserver {
  int _selectedIndex = 0;
  final _service = SupabaseService();

  final _dashboardKey = GlobalKey<DashboardScreenState>();
  final _posKey = GlobalKey<PosScreenState>();
  final _kelolaKey = GlobalKey<KelolaScreenState>();
  final _historyKey = GlobalKey<HistoryScreenState>();
  final _expensesKey = GlobalKey<ExpensesScreenState>();

  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _connectivity = Connectivity();

  StreamSubscription<List<ConnectivityResult>>? _connSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SyncStatusService.instance.refreshPendingCount();
    SyncStatusService.instance.lastSyncedAt.addListener(_onSyncedData);
    AutoSyncScheduler.instance.authFailureTick.addListener(_onAuthFailure);
    _initConnectivity();
    _runBackgroundCleanup();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AutoSyncScheduler.instance.start();
      _checkPickerCrash();
    });
  }

  Future<void> _checkPickerCrash() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final marker = File('${dir.path}/.picker_in_progress');
      if (!await marker.exists()) return;
      await marker.delete();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppTheme.dangerColor),
              SizedBox(width: 8),
              Expanded(child: Text('Deteksi Gangguan')),
            ],
          ),
          content: const Text(
            'Aplikasi sebelumnya berhenti saat membuka galeri foto.\n\n'
            'Kemungkinan penyebab:\n'
            '• Memori / RAM HP penuh\n'
            '• Penyimpanan hampir habis\n'
            '• Aplikasi galeri bermasalah\n\n'
            'Solusi yang disarankan:\n'
            '1. Restart HP\n'
            '2. Tutup aplikasi lain yang berjalan\n'
            '3. Kosongkan penyimpanan (min. 500 MB)\n'
            '4. Saat tambah foto, gunakan opsi "Ambil Foto" (kamera) jika galeri terus crash',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('MENGERTI'),
            ),
          ],
        ),
      );
    } catch (e) {
      debugPrint('_checkPickerCrash failed: $e');
    }
  }

  Future<void> _runBackgroundCleanup() async {
    await Future.delayed(const Duration(seconds: 3));
    if (!mounted) return;
    await _service.clearTempCache();
    await _service.cleanupOrphanedImages();
  }

  @override
  void dispose() {
  SyncStatusService.instance.lastSyncedAt.removeListener(_onSyncedData);
  AutoSyncScheduler.instance.authFailureTick.removeListener(_onAuthFailure);
  AutoSyncScheduler.instance.stop();
  _connSub?.cancel();
  WidgetsBinding.instance.removeObserver(this);
  super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _scheduleSync(delaySeconds: 1);
    } else if (state == AppLifecycleState.paused) {
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
    }
  }

  Future<void> _initConnectivity() async {
    try {
      final initial = await _connectivity.checkConnectivity();
      if (_hasConnection(initial)) {
        _scheduleSync(delaySeconds: 1);
      }
      _connSub = _connectivity.onConnectivityChanged.listen((results) {
        if (_hasConnection(results)) {
          _scheduleSync(delaySeconds: 3);
        }
      });
    } catch (e) {
      debugPrint('Connectivity init failed: $e');
    }
  }

  bool _hasConnection(List<ConnectivityResult> results) =>
      results.any((r) => r != ConnectivityResult.none);

  void _scheduleSync({int delaySeconds = 3}) {
    AutoSyncScheduler.instance
        .scheduleSync(delay: Duration(seconds: delaySeconds));
  }

  Future<void> _trySync() async {
    if (!_service.isLoggedIn) return;
    await AutoSyncScheduler.instance.triggerNow();
  }

  void _refreshAllScreens() {
    _dashboardKey.currentState?.refresh();
    _posKey.currentState?.reloadData();
    _kelolaKey.currentState?.reloadData();
    _historyKey.currentState?.reloadData();
    _expensesKey.currentState?.reloadData();
  }

  void _onSyncedData() {
    if (!mounted) return;
    _refreshAllScreens();
  }

  void _onAuthFailure() {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(SnackBar(
      content: const Text(
          'Sesi offline tidak dapat dipulihkan. Silakan login ulang untuk melanjutkan sinkronisasi.'),
      backgroundColor: AppTheme.dangerColor,
      duration: const Duration(seconds: 8),
      action: SnackBarAction(
        label: 'LOGIN',
        textColor: Colors.white,
        onPressed: _handleLogout,
      ),
    ));
  }

  Future<void> _handleLogout() async {
  _scaffoldKey.currentState?.closeDrawer();

  try {
    await _service.logout();
  } on PendingSyncException catch (e) {
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppTheme.dangerColor),
            SizedBox(width: 8),
            Expanded(child: Text('Data Belum Tersinkron')),
          ],
        ),
        content: Text(
          'Ada ${e.pendingCount} perubahan yang belum terkirim ke server '
          '(kemungkinan karena tidak ada internet).\n\n'
          'Jika Anda tetap logout, data tersebut akan hilang permanen '
          'dari HP ini.\n\n'
          'Saran: sambungkan internet, tunggu hingga sinkronisasi selesai, '
          'lalu logout lagi.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('BATAL'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.dangerColor,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('LOGOUT PAKSA'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;
    try {
      await _service.logout(force: true);
    } catch (err) {
      debugPrint('Forced logout failed: $err');
      AutoSyncScheduler.instance.start();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gagal logout. Coba lagi.'),
          backgroundColor: AppTheme.dangerColor,
        ),
      );
      return;
    }
  } catch (e) {
    debugPrint('Logout failed: $e');
    AutoSyncScheduler.instance.start();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Gagal logout. Coba lagi.'),
        backgroundColor: AppTheme.dangerColor,
      ),
    );
    return;
  }

  if (!mounted) return;
await Navigator.pushAndRemoveUntil(
  context,
  MaterialPageRoute(builder: (_) => const LoginScreen()),
  (route) => false,
);
}

  void _openMenu() {
    _scaffoldKey.currentState?.openDrawer();
  }

  void _selectDestination(int index) {
    _scaffoldKey.currentState?.closeDrawer();
    if (index == 6) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ReportsScreen()),
      );
      return;
    }
    if (index == 7) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ClosingScreen()),
      );
      return;
    }
    if (_selectedIndex == index) {
      _refreshTab(index);
      return;
    }
    setState(() => _selectedIndex = index);
    _refreshTab(index);
  }

  void _refreshTab(int index) {
    if (index == 0) {
      _dashboardKey.currentState?.refresh();
    } else if (index == 1) {
      _posKey.currentState?.reloadData();
    } else if (index == 2) {
      _kelolaKey.currentState?.reloadData();
    } else if (index == 3) {
      _historyKey.currentState?.reloadData();
    } else if (index == 4) {
      _expensesKey.currentState?.reloadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardScreen(
        key: _dashboardKey,
        onStartTransaction: () => _selectDestination(1),
      ),
      PosScreen(key: _posKey),
      KelolaScreen(key: _kelolaKey),
      HistoryScreen(key: _historyKey),
      ExpensesScreen(key: _expensesKey),
      const SettingsScreen(),
    ];

    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildDrawer(),
      body: MainMenuScope(
        openMenu: _openMenu,
        child: IndexedStack(
          index: _selectedIndex,
          children: pages,
        ),
      ),
    );
  }
}