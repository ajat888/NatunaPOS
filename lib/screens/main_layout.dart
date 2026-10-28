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

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> with WidgetsBindingObserver {
  int _selectedIndex = 0;
  final _service = SupabaseService();
  final _dashboardKey = GlobalKey<DashboardScreenState>();
  final _connectivity = Connectivity();

  StreamSubscription<List<ConnectivityResult>>? _connSub;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initConnectivity();
  }

  @override
  void dispose() {
    _connSub?.cancel();
    _debounceTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Saat user kembali ke aplikasi, coba sync (jika ada antrian).
    if (state == AppLifecycleState.resumed) {
      _scheduleSync(delaySeconds: 1);
    }
  }

  Future<void> _initConnectivity() async {
    try {
      // Cek koneksi awal — jika online, sync pertama setelah 1 detik.
      final initial = await _connectivity.checkConnectivity();
      if (_hasConnection(initial)) {
        _scheduleSync(delaySeconds: 1);
      }

      // Dengarkan perubahan koneksi. Debounce 3 detik agar tidak spam
      // saat sinyal goyang (Wi-Fi ↔ Data).
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
    try {
      await _service.syncData();
      // Refresh Beranda jika sedang tampil & widget masih mounted.
      if (mounted) {
        _dashboardKey.currentState?.refresh();
      }
    } catch (e) {
      debugPrint('Auto-sync failed: $e');
    }
  }

  Future<void> _handleLogout() async {
    await _service.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardScreen(
        key: _dashboardKey,
        onStartTransaction: () => setState(() => _selectedIndex = 1),
      ),
      const PosScreen(),
      const KelolaScreen(),
      const HistoryScreen(key: null),
    ];

    return Scaffold(
      body: Row(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              return Container(
                width: 105,
                decoration: const BoxDecoration(
                  color: AppTheme.surfaceColor,
                  border: Border(
                    right: BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                ),
                child: SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints:
                        BoxConstraints(minHeight: constraints.maxHeight),
                    child: NavigationRail(
                      backgroundColor: Colors.transparent,
                      selectedIndex: _selectedIndex,
                      onDestinationSelected: (int index) {
                        setState(() {
                          _selectedIndex = index;
                        });
                        if (index == 0) {
                          _dashboardKey.currentState?.refresh();
                        }
                      },
                      labelType: NavigationRailLabelType.all,
                      selectedIconTheme:
                          const IconThemeData(color: AppTheme.primaryColor),
                      selectedLabelTextStyle: const TextStyle(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                      unselectedIconTheme:
                          const IconThemeData(color: AppTheme.textLightColor),
                      unselectedLabelTextStyle: const TextStyle(
                        color: AppTheme.textLightColor,
                        fontSize: 12,
                      ),
                      leading: Padding(
                        padding: const EdgeInsets.only(top: 16, bottom: 8),
                        child: Column(
                          children: [
                            const Icon(Icons.storefront,
                                color: AppTheme.primaryColor, size: 32),
                            const SizedBox(height: 4),
                            Text(
                              'NatunaPOS',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryColor.withOpacity(0.8),
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Divider(height: 1),
                          ],
                        ),
                      ),
                      trailing: Padding(
                        padding: const EdgeInsets.only(top: 16, bottom: 24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Divider(height: 1),
                            const SizedBox(height: 8),
                            IconButton(
                              icon: const Icon(Icons.logout,
                                  color: AppTheme.dangerColor),
                              onPressed: _handleLogout,
                              tooltip: 'Keluar',
                            ),
                          ],
                        ),
                      ),
                      destinations: const [
                        NavigationRailDestination(
                          icon: Icon(Icons.dashboard_outlined),
                          selectedIcon: Icon(Icons.dashboard),
                          label: Text('Beranda'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.point_of_sale_outlined),
                          selectedIcon: Icon(Icons.point_of_sale),
                          label: Text('Kasir'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.inventory_2_outlined),
                          selectedIcon: Icon(Icons.inventory_2),
                          label: Text('Kelola'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.receipt_long_outlined),
                          selectedIcon: Icon(Icons.receipt_long),
                          label: Text('Riwayat'),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: pages,
            ),
          ),
        ],
      ),
    );
  }
}