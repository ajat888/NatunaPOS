// lib/screens/dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/theme.dart';
import '../services/supabase_service.dart';

class DashboardScreen extends StatefulWidget {
  final VoidCallback? onStartTransaction;
  const DashboardScreen({super.key, this.onStartTransaction});

  @override
  State<DashboardScreen> createState() => DashboardScreenState();
}

class DashboardScreenState extends State<DashboardScreen> {
  final _service = SupabaseService();
  int _totalSales = 0;
  int _transactionCount = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final summary = await _service.getTodaySummary();
      if (!mounted) return;
      setState(() {
        _totalSales = summary['total'] ?? 0;
        _transactionCount = summary['count'] ?? 0;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  /// Dipanggil dari MainLayout saat tab Beranda dipilih.
  Future<void> refresh() async {
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final formatCurrency = NumberFormat.decimalPattern('id');
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Beranda'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _load,
              tooltip: 'Muat ulang'),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ringkasan Hari Ini',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.textColor,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                _buildSummaryCard(
                  title: 'Total Penjualan',
                  value: _isLoading
                      ? '—'
                      : 'Rp ${formatCurrency.format(_totalSales)}',
                  icon: Icons.account_balance_wallet_outlined,
                ),
                const SizedBox(width: 16),
                _buildSummaryCard(
                  title: 'Jumlah Transaksi',
                  value: _isLoading ? '—' : '$_transactionCount',
                  icon: Icons.receipt_outlined,
                ),
              ],
            ),
            const Spacer(),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Siap melayani pelanggan?',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Buka menu Kasir untuk mulai membuat pesanan baru.',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppTheme.primaryColor,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 20),
                    ),
                    onPressed: widget.onStartTransaction,
                    child: const Text('MULAI TRANSAKSI'),
                  ),
                ],
              ),
            ),
            const Spacer(flex: 2),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(
      {required String title, required String value, required IconData icon}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppTheme.textLightColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.textLightColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              value,
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: AppTheme.textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}