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
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SyncStatusService.instance.refreshPendingCount();
    SyncStatusService.instance.state.addListener(_onSyncStateChanged);
    _initConnectivity();
    _runBackgroundCleanup();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkPickerCrash());
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
    SyncStatusService.instance.state.removeListener(_onSyncStateChanged);
    _connSub?.cancel();
    _debounceTimer?.cancel();
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
    _debounceTimer?.cancel();
    _debounceTimer = Timer(Duration(seconds: delaySeconds), _trySync);
  }

  Future<void> _trySync() async {
    if (!_service.isLoggedIn) return;

    if (_service.isOfflineSession) {
      final success = await _service.tryAutoLoginAndSync();
      if (success && mounted) {
        _refreshAllScreens();
      }
      return;
    }

    try {
      await _service.syncData();
      if (mounted) {
        _refreshAllScreens();
      }
    } catch (e) {
      debugPrint('Auto-sync failed: $e');
    }
  }

  void _refreshAllScreens() {
    _dashboardKey.currentState?.refresh();
    _posKey.currentState?.reloadData();
    _kelolaKey.currentState?.reloadData();
    _historyKey.currentState?.reloadData();
    _expensesKey.currentState?.reloadData();
  }

  void _onSyncStateChanged() {
    if (!mounted) return;
    final state = SyncStatusService.instance.state.value;
    if (state == SyncState.failed &&
        SyncStatusService.instance.shouldNotifyFailure()) {
      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(SnackBar(
        content: Text(
          SyncStatusService.instance.lastErrorMessage ??
              'Sinkronisasi gagal. Akan dicoba lagi otomatis.',
        ),
        backgroundColor: AppTheme.dangerColor,
        duration: const Duration(seconds: 6),
        action: SnackBarAction(
          label: 'COBA',
          textColor: Colors.white,
          onPressed: _trySync,
        ),
      ));
    }
  }

  Future<void> _handleLogout() async {
    _scaffoldKey.currentState?.closeDrawer();
    await _service.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
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