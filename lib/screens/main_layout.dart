import 'package:flutter/material.dart';
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

class _MainLayoutState extends State<MainLayout> {
  int _selectedIndex = 0;
  final _service = SupabaseService();

  // IndexedStack menjaga state semua halaman tetap hidup
  static const List<Widget> _pages = [
    DashboardScreen(),
    PosScreen(),
    KelolaScreen(),
    HistoryScreen(),
  ];

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
    return Scaffold(
      body: Row(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              return Container(
                // PERBAIKAN: Lebar ditambah dari 80 menjadi 90 agar teks tidak terpotong
                width: 90, 
                decoration: const BoxDecoration(
                  color: AppTheme.surfaceColor,
                  border: Border(
                    right: BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                ),
                child: SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    // PERBAIKAN: Menghapus IntrinsicHeight untuk mencegah bug menu ganda
                    child: NavigationRail(
                      backgroundColor: Colors.transparent,
                      selectedIndex: _selectedIndex,
                      onDestinationSelected: (int index) {
                        setState(() {
                          _selectedIndex = index;
                        });
                      },
                      labelType: NavigationRailLabelType.all,
                      selectedIconTheme: const IconThemeData(color: AppTheme.primaryColor),
                      selectedLabelTextStyle: const TextStyle(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12, // Ukuran font disesuaikan agar pas
                      ),
                      unselectedIconTheme: const IconThemeData(color: AppTheme.textLightColor),
                      unselectedLabelTextStyle: const TextStyle(
                        color: AppTheme.textLightColor,
                        fontSize: 12,
                      ),
                      leading: Padding(
                        padding: const EdgeInsets.only(top: 16, bottom: 8),
                        child: Column(
                          children: [
                            const Icon(Icons.storefront, color: AppTheme.primaryColor, size: 32),
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
                              icon: const Icon(Icons.logout, color: AppTheme.dangerColor),
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
                          // PERBAIKAN: maxLines: 1 memastikan teks tetap satu baris
                          label: Text('Beranda', maxLines: 1, softWrap: false),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.point_of_sale_outlined),
                          selectedIcon: Icon(Icons.point_of_sale),
                          label: Text('Kasir', maxLines: 1, softWrap: false),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.inventory_2_outlined),
                          selectedIcon: Icon(Icons.inventory_2),
                          label: Text('Kelola', maxLines: 1, softWrap: false),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.receipt_long_outlined),
                          selectedIcon: Icon(Icons.receipt_long),
                          label: Text('Riwayat', maxLines: 1, softWrap: false),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          
          // Area Konten Utama
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: _pages,
            ),
          ),
        ],
      ),
    );
  }
}