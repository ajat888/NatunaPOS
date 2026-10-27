import 'package:flutter/material.dart';
import '../core/theme.dart';
import 'dashboard_screen.dart';
import 'pos_screen.dart';
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

  // Daftar halaman yang akan ditampilkan
  final List<Widget> _pages = [
    const DashboardScreen(),
    const PosScreen(),
    const HistoryScreen(),
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
          // Navigation Rail (Menu Samping)
          NavigationRail(
            backgroundColor: AppTheme.surfaceColor,
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
            ),
            unselectedIconTheme: const IconThemeData(color: AppTheme.textLightColor),
            unselectedLabelTextStyle: const TextStyle(color: AppTheme.textLightColor),
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: [
                  const Icon(Icons.storefront, color: AppTheme.primaryColor, size: 32),
                  const SizedBox(height: 8),
                  Text(
                    'NatunaPOS',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor.withOpacity(0.8),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Divider(),
                ],
              ),
            ),
            trailing: Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: IconButton(
                    icon: const Icon(Icons.logout, color: AppTheme.dangerColor),
                    onPressed: _handleLogout,
                    tooltip: 'Keluar',
                  ),
                ),
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
                icon: Icon(Icons.receipt_long_outlined),
                selectedIcon: Icon(Icons.receipt_long),
                label: Text('Riwayat'),
              ),
            ],
          ),
          // Garis pemisah vertikal tipis (khas UI korporat)
          const VerticalDivider(thickness: 1, width: 1, color: Color(0xFFE2E8F0)),
          
          // Area Konten Utama
          Expanded(
            child: _pages[_selectedIndex],
          ),
        ],
      ),
    );
  }
}