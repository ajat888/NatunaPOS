import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/breakpoints.dart';
import '../core/theme.dart';
import '../core/local_db.dart';
import '../core/fixed_cost_settings.dart';
import '../services/supabase_service.dart';
import '../services/expense_service.dart';
import '../services/sync_status_service.dart';
import '../widgets/common/main_menu_scope.dart';

class DashboardScreen extends StatefulWidget {
  final VoidCallback? onStartTransaction;
  const DashboardScreen({super.key, this.onStartTransaction});

  @override
  State<DashboardScreen> createState() => DashboardScreenState();
}

class DashboardScreenState extends State<DashboardScreen> {
  final _service = SupabaseService();
  final _expenseService = ExpenseService.instance;
  final _localDb = LocalDb.instance;
  
  int _totalSales = 0;
  int _transactionCount = 0;
  int _totalExpenses = 0;
  int _openOrdersCount = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
    // Mendengarkan perubahan pending count sebagai proxy untuk write notifier
    SyncStatusService.instance.pendingCount.addListener(_onPendingCountChanged);
  }

  @override
  void dispose() {
    SyncStatusService.instance.pendingCount.removeListener(_onPendingCountChanged);
    super.dispose();
  }

  void _onPendingCountChanged() {
    _loadOpenOrders();
  }

  Future<void> _loadOpenOrders() async {
    try {
      final orders = await _localDb.getOpenOrders();
      if (!mounted) return;
      setState(() {
        _openOrdersCount = orders.length;
      });
    } catch (_) {}
  }

  Future<void> _load() async {
    try {
      final summary = await _service.getTodaySummary();
      final expenses = await _expenseService.getTodayExpenseTotal();
      final orders = await _localDb.getOpenOrders();
      if (!mounted) return;
      setState(() {
        _totalSales = summary['total'] ?? 0;
        _transactionCount = summary['count'] ?? 0;
        _totalExpenses = expenses;
        _openOrdersCount = orders.length;
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: widget.onStartTransaction,
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_shopping_cart),
        label: const Text('MULAI TRANSAKSI'),
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
            _buildTacticalSignals(formatCurrency: formatCurrency),
            const SizedBox(height: 24),
            ValueListenableBuilder<int>(
              valueListenable: FixedCostSettings.instance.monthly,
              builder: (context, monthlyFixed, _) {
                final now = DateTime.now();
                final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
                final dailyFixedCost = monthlyFixed > 0 ? (monthlyFixed / daysInMonth).round() : 0;
                final kontribusiHarian = _totalSales - _totalExpenses;
                final labaBersihSebenarnya = kontribusiHarian - dailyFixedCost;
                final targetHarian = dailyFixedCost;
                final progress = targetHarian > 0 ? (_totalSales / targetHarian).clamp(0.0, 1.0) : 1.0;
                final isBepReached = _totalSales >= targetHarian && targetHarian > 0;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (targetHarian > 0) ...[
                      _buildBepProgress(
                        targetHarian: targetHarian,
                        totalSales: _totalSales,
                        progress: progress,
                        isBepReached: isBepReached,
                        formatCurrency: formatCurrency,
                      ),
                      const SizedBox(height: 24),
                    ],
                    if (isCompact) ...[
                      _buildSummaryCard(
                        title: 'Total Penjualan',
                        value: _isLoading ? '—' : 'Rp ${formatCurrency.format(_totalSales)}',
                        icon: Icons.account_balance_wallet_outlined,
                      ),
                      const SizedBox(height: 16),
                      _buildSummaryCard(
                        title: 'Jumlah Transaksi',
                        value: _isLoading ? '—' : '$_transactionCount',
                        icon: Icons.receipt_outlined,
                      ),
                      const SizedBox(height: 16),
                      _buildSummaryCard(
                        title: 'Pengeluaran',
                        value: _isLoading ? '—' : '- Rp ${formatCurrency.format(_totalExpenses)}',
                        icon: Icons.money_off,
                        isDanger: _totalExpenses > 0,
                      ),
                      const SizedBox(height: 16),
                      _buildSummaryCard(
                        title: 'Laba Bersih (Estimasi)',
                        value: _isLoading ? '—' : 'Rp ${formatCurrency.format(labaBersihSebenarnya)}',
                        icon: Icons.trending_up,
                        isDanger: labaBersihSebenarnya < 0,
                        isPositive: labaBersihSebenarnya >= 0,
                      ),
                    ] else ...[
                      Row(
                        children: [
                          _buildSummaryCard(
                            title: 'Total Penjualan',
                            value: _isLoading ? '—' : 'Rp ${formatCurrency.format(_totalSales)}',
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
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          _buildSummaryCard(
                            title: 'Pengeluaran',
                            value: _isLoading ? '—' : '- Rp ${formatCurrency.format(_totalExpenses)}',
                            icon: Icons.money_off,
                            isDanger: _totalExpenses > 0,
                            expanded: true,
                          ),
                          const SizedBox(width: 16),
                          _buildSummaryCard(
                            title: 'Laba Bersih (Estimasi)',
                            value: _isLoading ? '—' : 'Rp ${formatCurrency.format(labaBersihSebenarnya)}',
                            icon: Icons.trending_up,
                            isDanger: labaBersihSebenarnya < 0,
                            isPositive: labaBersihSebenarnya >= 0,
                            expanded: true,
                          ),
                        ],
                      ),
                    ],
                  ],
                );
              },
            ),
            const SizedBox(height: 80), // Ruang untuk FAB
          ],
        ),
      ),
    );
  }

  Widget _buildTacticalSignals({required NumberFormat formatCurrency}) {
    return ValueListenableBuilder<int>(
      valueListenable: SyncStatusService.instance.pendingCount,
      builder: (context, pendingCount, _) {
        return ValueListenableBuilder<SyncState>(
          valueListenable: SyncStatusService.instance.state,
          builder: (context, syncState, _) {
            final hasSyncIssue = pendingCount > 0 || syncState == SyncState.failed;
            final hasOpenOrders = _openOrdersCount > 0;

            if (!hasSyncIssue && !hasOpenOrders) return const SizedBox.shrink();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Sinyal Taktis',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textColor,
                  ),
                ),
                const SizedBox(height: 12),
                if (hasOpenOrders)
                  _buildSignalCard(
                    icon: Icons.restaurant_menu,
                    title: 'Pesanan Aktif',
                    subtitle: '$_openOrdersCount pesanan belum dibayar',
                    color: Colors.orange.shade700,
                    onTap: widget.onStartTransaction,
                  ),
                if (hasOpenOrders && hasSyncIssue) const SizedBox(height: 12),
                if (hasSyncIssue)
                  _buildSignalCard(
                    icon: syncState == SyncState.failed ? Icons.sync_problem : Icons.cloud_upload_outlined,
                    title: syncState == SyncState.failed ? 'Sinkronisasi Gagal' : 'Data Tertunda',
                    subtitle: syncState == SyncState.failed 
                        ? 'Cek koneksi internet Anda' 
                        : '$pendingCount perubahan belum terkirim ke server',
                    color: AppTheme.dangerColor,
                    onTap: () {
                      SupabaseService().syncData();
                    },
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildSignalCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.textColor,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: color),
          ],
        ),
      ),
    );
  }

  Widget _buildBepProgress({
    required int targetHarian,
    required int totalSales,
    required double progress,
    required bool isBepReached,
    required NumberFormat formatCurrency,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Target BEP Harian',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textColor,
                ),
              ),
              Text(
                isBepReached ? 'TERCAPAI' : 'BELUM TERCAPAI',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isBepReached ? Colors.green.shade700 : AppTheme.dangerColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 12,
              backgroundColor: const Color(0xFFE2E8F0),
              valueColor: AlwaysStoppedAnimation<Color>(
                isBepReached ? Colors.green.shade700 : AppTheme.primaryColor,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Omzet: Rp ${formatCurrency.format(totalSales)}',
                style: const TextStyle(fontSize: 14, color: AppTheme.textLightColor),
              ),
              Text(
                'Target: Rp ${formatCurrency.format(targetHarian)}',
                style: const TextStyle(fontSize: 14, color: AppTheme.textLightColor),
              ),
            ],
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
    bool isDanger = false,
    bool isPositive = false,
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
              Icon(icon, color: isDanger ? AppTheme.dangerColor : AppTheme.textLightColor, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  color: isDanger ? AppTheme.dangerColor : AppTheme.textLightColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: isDanger ? AppTheme.dangerColor : (isPositive ? Colors.green.shade700 : AppTheme.textColor),
            ),
          ),
        ],
      ),
    );
    return expanded ? Expanded(child: card) : card;
  }
}