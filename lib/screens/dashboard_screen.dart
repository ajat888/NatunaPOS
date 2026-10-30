// lib/screens/dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/breakpoints.dart';
import '../core/theme.dart';
import '../services/supabase_service.dart';
import '../widgets/common/main_menu_scope.dart';

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

  Future<void> refresh() async {
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final formatCurrency = NumberFormat.decimalPattern('id');
    final size = Breakpoints.of(context);
    final isCompact = size.isCompact;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          tooltip: 'Menu',
          onPressed: () => MainMenuScope.of(context)?.openMenu(),
        ),
        title: const Text('Beranda'),
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _load,
              tooltip: 'Muat ulang'),
        ],
      ),
      body: SingleChildScrollView(
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
            if (isCompact) ...[
              _buildSummaryCard(
                title: 'Total Penjualan',
                value: _isLoading
                    ? '—'
                    : 'Rp ${formatCurrency.format(_totalSales)}',
                icon: Icons.account_balance_wallet_outlined,
              ),
              const SizedBox(height: 16),
              _buildSummaryCard(
                title: 'Jumlah Transaksi',
                value: _isLoading ? '—' : '$_transactionCount',
                icon: Icons.receipt_outlined,
              ),
            ] else
              Row(
                children: [
                  _buildSummaryCard(
                    title: 'Total Penjualan',
                    value: _isLoading
                        ? '—'
                        : 'Rp ${formatCurrency.format(_totalSales)}',
                    icon: Icons.account_balance_wallet_outlined,
                    expanded: true,
                  ),
                  const SizedBox(width: 16),
                  _buildSummaryCard(
                    title: 'Jumlah Transaksi',
                    value: _isLoading ? '—' : '$_transactionCount',
                    icon: Icons.receipt_outlined,
                    expanded: true,
                  ),
                ],
              ),
            const SizedBox(height: 24),
            // PERUBAHAN DI SINI: Hanya tampil jika belum ada transaksi hari ini
            if (_transactionCount == 0) 
              _buildCallToAction(isCompact: isCompact),
          ],
        ),
      ),
    );
  }

  Widget _buildCallToAction({required bool isCompact}) {
    if (isCompact) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.primaryColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Siap melayani pelanggan?',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Buka menu Kasir untuk mulai membuat pesanan baru.',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppTheme.primaryColor,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
              ),
              onPressed: widget.onStartTransaction,
              child: const Text('MULAI TRANSAKSI'),
            ),
          ],
        ),
      );
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Expanded(
            child: Column(
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
          ),
          const SizedBox(width: 16),
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
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required IconData icon,
    bool expanded = false,
  }) {
    final card = Container(
      width: double.infinity,
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
    );
    return expanded ? Expanded(child: card) : card;
  }
}