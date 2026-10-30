// lib/screens/main_layout.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../core/theme.dart';
import 'dashboard_screen.dart';
import 'pos_screen.dart';
import 'kelola_screen.dart';
import 'history_screen.dart';
import 'login_screen.dart';
import '../services/supabase_service.dart';
import '../services/sync_status_service.dart';
import '../widgets/common/main_menu_scope.dart';

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

    // Jika sedang login offline, coba auto-login pakai secure storage
    if (_service.isOfflineSession) {
      final success = await _service.tryAutoLoginAndSync();
      if (success && mounted) {
        _refreshAllScreens();
      }
      return; // Hentikan proses di sini, karena tryAutoLoginAndSync sudah memanggil syncData
    }

    // Sync normal (jika sudah login online)
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
    }
  }

  Widget _buildSyncBadge() {
    return ValueListenableBuilder<SyncState>(
      valueListenable: SyncStatusService.instance.state,
      builder: (context, state, _) {
        IconData icon;
        Color color;
        String label;
        String tooltip;
        switch (state) {
          case SyncState.syncing:
            icon = Icons.sync;
            color = AppTheme.primaryColor;
            label = 'SYNC';
            tooltip = 'Menyinkronkan...';
            break;
          case SyncState.pending:
            icon = Icons.cloud_upload_outlined;
            color = Colors.orange.shade800;
            label = '${SyncStatusService.instance.pendingCount.value}';
            tooltip =
                '${SyncStatusService.instance.pendingCount.value} perubahan menunggu. Ketuk untuk sync.';
            break;
          case SyncState.failed:
            icon = Icons.cloud_off;
            color = AppTheme.dangerColor;
            label = 'GAGAL';
            tooltip = 'Sinkronisasi gagal. Ketuk untuk coba lagi.';
            break;
          case SyncState.idle:
            icon = Icons.cloud_done_outlined;
            color = Colors.green.shade700;
            label = 'OK';
            tooltip = 'Semua data tersinkron. Ketuk untuk sync manual.';
            break;
        }
        return Tooltip(
          message: tooltip,
          child: InkWell(
            borderRadius: BorderRadius.circular(4),
            onTap: _trySync,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 13, color: color),
                  const SizedBox(width: 4),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDrawerItem(int index, IconData icon, String label) {
    final isSelected = _selectedIndex == index;
    return ListTile(
      selected: isSelected,
      selectedTileColor: AppTheme.primaryColor.withOpacity(0.08),
      leading: Icon(
        icon,
        color: isSelected ? AppTheme.primaryColor : AppTheme.textLightColor,
      ),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          color: isSelected ? AppTheme.primaryColor : AppTheme.textColor,
        ),
      ),
      onTap: () => _selectDestination(index),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      width: 280,
      backgroundColor: AppTheme.surfaceColor,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Row(
                children: [
                  const Icon(Icons.storefront,
                      color: AppTheme.primaryColor, size: 32),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'NatunaPOS',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textColor,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Point of Sale',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textLightColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  const Text(
                    'STATUS SYNC',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.textLightColor,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const Spacer(),
                  _buildSyncBadge(),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _buildDrawerItem(0, Icons.dashboard_outlined, 'Beranda'),
                  _buildDrawerItem(1, Icons.point_of_sale_outlined, 'Kasir'),
                  _buildDrawerItem(2, Icons.inventory_2_outlined, 'Kelola'),
                  _buildDrawerItem(3, Icons.receipt_long_outlined, 'Riwayat'),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.sync, color: AppTheme.primaryColor),
              title: const Text('Sync Sekarang'),
              onTap: () {
                _scaffoldKey.currentState?.closeDrawer();
                _trySync();
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: AppTheme.dangerColor),
              title: const Text(
                'Keluar',
                style: TextStyle(color: AppTheme.dangerColor),
              ),
              onTap: _handleLogout,
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
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