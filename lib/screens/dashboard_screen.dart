import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/breakpoints.dart';
import '../core/fixed_cost_settings.dart';
import '../core/local_db.dart';
import '../core/theme.dart';
import '../services/auto_sync_scheduler.dart';
import '../services/expense_service.dart';
import '../services/supabase_service.dart';
import '../services/sync_status_service.dart';
import '../widgets/common/main_menu_scope.dart';

part 'dashboard/dashboard_target_card.dart';
part 'dashboard/dashboard_signal_cards.dart';

class DashboardScreen extends StatefulWidget {
  final VoidCallback? onStartTransaction;
  const DashboardScreen({super.key, this.onStartTransaction});

  @override
  State<DashboardScreen> createState() => DashboardScreenState();
}

class DashboardScreenState extends State<DashboardScreen> {
  final _service = SupabaseService();
  final _expenseService = ExpenseService.instance;

  int _totalSales = 0;
  int _transactionCount = 0;
  int _totalExpenses = 0;
  int _totalHpp = 0;
  int _voidCount = 0;
  int _voidTotal = 0;
  int _openOrderCount = 0;
  int _openOrderValue = 0;
  int _oldestOrderMinutes = 0;
  int _monthlyFixedCost = 0;
  List<Map<String, dynamic>> _topProducts = const [];
  bool _isLoading = true;
  Timer? _reloadDebounce;

  @override
  void initState() {
    super.initState();
    SyncStatusService.instance.pendingCount.addListener(_onPendingChanged);
    unawaited(_load());
  }

  @override
  void dispose() {
    _reloadDebounce?.cancel();
    SyncStatusService.instance.pendingCount.removeListener(_onPendingChanged);
    super.dispose();
  }

  void _onPendingChanged() {
    if (!mounted) return;
    _reloadDebounce?.cancel();
    _reloadDebounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      unawaited(_load());
    });
  }

  Future<void> _load() async {
    try {
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, now.day);
      final end = DateTime(now.year, now.month, now.day + 1);
      final summary = await _service.getTodaySummary();
      final expenses = await _expenseService.getTodayExpenseTotal();
      final hpp = await LocalDb.instance.getHppBetween(start, end);
      final voided =
          await LocalDb.instance.getVoidTransactionsSummaryBetween(start, end);
      final orders = await LocalDb.instance.getOpenOrders();
      final performance =
          await LocalDb.instance.getProductPerformanceBetween(start, end);
      await FixedCostSettings.instance.load();
      if (!mounted) return;
      final ranked = List<Map<String, dynamic>>.from(performance)
        ..sort((a, b) => ((b['qty_sold'] as int?) ?? 0)
            .compareTo((a['qty_sold'] as int?) ?? 0));
      var openValue = 0;
      var oldest = 0;
      for (final order in orders) {
        openValue += order.subtotal;
        final age = now.difference(order.createdAt).inMinutes;
        if (age > oldest) oldest = age;
      }
      setState(() {
        _totalSales = summary['total'] ?? 0;
        _transactionCount = summary['count'] ?? 0;
        _totalExpenses = expenses;
        _totalHpp = hpp;
        _voidCount = voided['count'] ?? 0;
        _voidTotal = voided['total'] ?? 0;
        _openOrderCount = orders.length;
        _openOrderValue = openValue;
        _oldestOrderMinutes = oldest;
        _monthlyFixedCost = FixedCostSettings.instance.currentMonthly;
        _topProducts = ranked.take(3).toList();
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

  Future<void> _refreshAll() async {
    await AutoSyncScheduler.instance.triggerNow();
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final formatCurrency = NumberFormat.decimalPattern('id');
    final size = Breakpoints.of(context);
    final isCompact = size.isCompact;
    final kontribusi = _totalSales - _totalHpp - _totalExpenses;
    final marginRatio =
        _totalSales > 0 ? (_totalSales - _totalHpp) / _totalSales : 0.0;

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
            icon: const Icon(Icons.point_of_sale),
            onPressed: widget.onStartTransaction,
            tooltip: 'Mulai Transaksi',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshAll,
            tooltip: 'Muat ulang',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshAll,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
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
                const SizedBox(height: 16),
                _buildSummaryCard(
                  title: 'Pengeluaran',
                  value: _isLoading
                      ? '—'
                      : '- Rp ${formatCurrency.format(_totalExpenses)}',
                  icon: Icons.money_off,
                  isDanger: _totalExpenses > 0,
                ),
                const SizedBox(height: 16),
                _buildSummaryCard(
                  title: 'Kontribusi Harian',
                  value: _isLoading
                      ? '—'
                      : 'Rp ${formatCurrency.format(kontribusi)}',
                  icon: Icons.trending_up,
                  isDanger: kontribusi < 0,
                  isPositive: kontribusi >= 0,
                ),
              ] else ...[
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
                const SizedBox(height: 16),
                Row(
                  children: [
                    _buildSummaryCard(
                      title: 'Pengeluaran',
                      value: _isLoading
                          ? '—'
                          : '- Rp ${formatCurrency.format(_totalExpenses)}',
                      icon: Icons.money_off,
                      isDanger: _totalExpenses > 0,
                      expanded: true,
                    ),
                    const SizedBox(width: 16),
                    _buildSummaryCard(
                      title: 'Kontribusi Harian',
                      value: _isLoading
                          ? '—'
                          : 'Rp ${formatCurrency.format(kontribusi)}',
                      icon: Icons.trending_up,
                      isDanger: kontribusi < 0,
                      isPositive: kontribusi >= 0,
                      expanded: true,
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              _DashboardTargetCard(
                isLoading: _isLoading,
                monthlyFixedCost: _monthlyFixedCost,
                contribution: kontribusi,
                marginRatio: marginRatio,
              ),
              const SizedBox(height: 16),
              const _DashboardSyncCard(),
              if (_openOrderCount > 0) ...[
                const SizedBox(height: 16),
                _DashboardOpenOrdersCard(
                  count: _openOrderCount,
                  value: _openOrderValue,
                  oldestMinutes: _oldestOrderMinutes,
                  onTap: widget.onStartTransaction,
                ),
              ],
              if (_voidCount > 0) ...[
                const SizedBox(height: 16),
                _DashboardVoidCard(count: _voidCount, total: _voidTotal),
              ],
              if (_topProducts.isNotEmpty) ...[
                const SizedBox(height: 16),
                _DashboardTopProductsCard(products: _topProducts),
              ],
              const SizedBox(height: 24),
              if (_transactionCount == 0)
                _buildCallToAction(isCompact: isCompact),
            ],
          ),
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
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
              Icon(icon,
                  color: isDanger
                      ? AppTheme.dangerColor
                      : AppTheme.textLightColor,
                  size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  color: isDanger
                      ? AppTheme.dangerColor
                      : AppTheme.textLightColor,
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
              color: isDanger
                  ? AppTheme.dangerColor
                  : (isPositive
                      ? Colors.green.shade700
                      : AppTheme.textColor),
            ),
          ),
        ],
      ),
    );
    return expanded ? Expanded(child: card) : card;
  }
}