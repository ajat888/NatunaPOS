import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';
import '../core/breakpoints.dart';
import '../core/theme.dart';
import '../models/expense.dart';
import '../models/history_entry.dart';
import '../models/transaction.dart';
import '../services/expense_service.dart';
import '../services/supabase_service.dart';
import '../services/printer_service.dart';
import '../widgets/common/main_menu_scope.dart';
import 'voided_open_orders_screen.dart';

part 'history/history_list_tile.dart';
part 'history/void_dialog.dart';
part 'history/history_date_bar.dart';
part 'history/history_summary_cards.dart';
part 'history/history_expense_tile.dart';
part 'history/history_type_label.dart';

enum HistoryFilter { all, sales, expenses }

class HistoryScreen extends StatefulWidget {
  final Future<void> Function()? onDataChanged;

  const HistoryScreen({super.key, this.onDataChanged});

  @override
  State<HistoryScreen> createState() => HistoryScreenState();
}

class HistoryScreenState extends State<HistoryScreen> {
  final _service = SupabaseService();
  final _expenseService = ExpenseService.instance;
  DateTime _selectedDate = _dateOnly(DateTime.now());
  HistoryFilter _filter = HistoryFilter.all;
  List<HistoryEntry> _entries = [];
  int _salesTotal = 0;
  int _salesCount = 0;
  int _expenseTotal = 0;
  int _expenseCount = 0;
  bool _showVoided = true;
  bool _isLoading = true;
  String? _errorMessage;

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  bool get _isToday => _selectedDate == _dateOnly(DateTime.now());

  @override
  void initState() {
    super.initState();
    reloadData(showLoading: true);
  }

  Future<void> reloadData({bool showLoading = false}) async {
    if (mounted) {
      setState(() {
        if (showLoading) _isLoading = true;
        _errorMessage = null;
      });
    }
    try {
      final start = _selectedDate;
      final end = DateTime(start.year, start.month, start.day + 1);
      final sales = await _service.getLocalSalesForRange(start, end);
      final salesSummary =
          await _service.getLocalSalesSummaryForRange(start, end);
      final expenses = await _expenseService.getLocalExpensesForRange(start, end);
      final expenseSummary =
          await _expenseService.getLocalExpenseSummaryForRange(start, end);
      if (!mounted) return;
      setState(() {
        _entries = [
          ...sales.map(HistoryEntry.fromSale),
          ...expenses.map(HistoryEntry.fromExpense),
        ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        _salesTotal = salesSummary['total'] ?? 0;
        _salesCount = salesSummary['count'] ?? 0;
        _expenseTotal = expenseSummary['total'] ?? 0;
        _expenseCount = expenseSummary['count'] ?? 0;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Gagal memuat riwayat.';
      });
    }
  }

  Future<void> _afterDataChanged() async {
    await reloadData();
    await widget.onDataChanged?.call();
  }

  void _shiftDate(int days) {
    final next =
        DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day + days);
    if (next.isAfter(_dateOnly(DateTime.now()))) return;
    setState(() => _selectedDate = next);
    reloadData(showLoading: true);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: _dateOnly(DateTime.now()),
    );
    if (picked == null) return;
    setState(() => _selectedDate = _dateOnly(picked));
    await reloadData(showLoading: true);
  }

  String _displayTable(Transaction tx) {
    final t = tx.tableNumber;
    if (t == null || t.isEmpty) return '-';
    if (tx.orderType == 'dine_in' && t.startsWith('M-')) {
      final n = int.tryParse(t.substring(2));
      if (n != null) return 'Meja $n';
    }
    return t;
  }

  Future<void> _reprint(Transaction tx) async {
    if (kIsWeb) return;
    final ok = await PrinterService.instance.printReceipt(tx);
    if (!mounted) return;
    final msg = !ok
        ? 'Gagal cetak struk. Periksa printer.'
        : (tx.isVoided ? 'Struk VOID dicetak' : 'Struk berhasil dicetak');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: ok ? Colors.green : AppTheme.dangerColor,
      ),
    );
  }

  Future<void> _openVoidDialog(Transaction tx) async {
    if (kIsWeb || tx.isVoided) return;
    final reason = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _VoidDialog(transaction: tx),
    );
    if (reason == null) return;
    final trimmed = reason.trim();
    if (trimmed.length < 5) return;
    try {
      await _service.voidTransaction(id: tx.id, reason: trimmed);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transaksi di-void'),
          backgroundColor: Colors.green,
        ),
      );
      await _afterDataChanged();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Gagal void: ${e.toString().replaceAll('Exception: ', '')}'),
          backgroundColor: AppTheme.dangerColor,
        ),
      );
    }
  }

  Future<void> _voidExpense(Expense exp) async {
    if (kIsWeb) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        title: const Text('Void Pengeluaran'),
        content: Text(
            'Yakin ingin membatalkan pengeluaran "${exp.itemName}" sebesar Rp ${NumberFormat.decimalPattern('id').format(exp.amount)}?\nData tidak akan dihapus permanen (audit).'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('BATAL')),
          ElevatedButton(
              style:
                  ElevatedButton.styleFrom(backgroundColor: AppTheme.dangerColor),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('VOID')),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _expenseService.voidExpense(exp.id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Gagal void: ${e.toString().replaceAll('Exception: ', '')}'),
          backgroundColor: AppTheme.dangerColor,
        ),
      );
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Pengeluaran di-void'), backgroundColor: Colors.green));
    await _afterDataChanged();
  }

  void _openVoidedOpenOrders() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const VoidedOpenOrdersScreen()),
    );
  }

  List<HistoryEntry> get _visibleEntries {
    return _entries.where((e) {
      if (_filter == HistoryFilter.sales && e.kind != HistoryKind.sale) {
        return false;
      }
      if (_filter == HistoryFilter.expenses && e.kind != HistoryKind.expense) {
        return false;
      }
      if (!_showVoided && (e.transaction?.isVoided ?? false)) return false;
      return true;
    }).toList();
  }

  String _filterLabel(HistoryFilter filter) {
    switch (filter) {
      case HistoryFilter.all:
        return 'Semua';
      case HistoryFilter.sales:
        return 'Penjualan';
      case HistoryFilter.expenses:
        return 'Pengeluaran';
    }
  }

  @override
  Widget build(BuildContext context) {
    final formatCurrency = NumberFormat.decimalPattern('id');
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          tooltip: 'Menu',
          onPressed: () => MainMenuScope.of(context)?.openMenu(),
        ),
        title: const Text('Riwayat'),
        actions: [
          if (!kIsWeb)
            IconButton(
              icon: const Icon(Icons.block),
              tooltip: 'Void Open Order',
              onPressed: _openVoidedOpenOrders,
            ),
          IconButton(
            icon: Icon(_showVoided ? Icons.visibility : Icons.visibility_off),
            tooltip: _showVoided ? 'Sembunyikan VOID' : 'Tampilkan VOID',
            onPressed: () => setState(() => _showVoided = !_showVoided),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => reloadData(showLoading: true),
            tooltip: 'Muat ulang',
          ),
        ],
      ),
      body: Column(
        children: [
          _HistoryDateBar(
            date: _selectedDate,
            isToday: _isToday,
            onPrev: () => _shiftDate(-1),
            onNext: _isToday ? null : () => _shiftDate(1),
            onPick: _pickDate,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: _HistorySummaryCards(
              salesTotal: _salesTotal,
              salesCount: _salesCount,
              expenseTotal: _expenseTotal,
              expenseCount: _expenseCount,
              formatCurrency: formatCurrency,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Wrap(
              spacing: 8,
              children: HistoryFilter.values.map((filter) {
                final selected = _filter == filter;
                return ChoiceChip(
                  label: Text(_filterLabel(filter)),
                  selected: selected,
                  onSelected: (_) => setState(() => _filter = filter),
                  selectedColor: AppTheme.primaryColor.withOpacity(0.12),
                  labelStyle: TextStyle(
                    color: selected
                        ? AppTheme.primaryColor
                        : AppTheme.textLightColor,
                    fontWeight:
                        selected ? FontWeight.bold : FontWeight.normal,
                  ),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                );
              }).toList(),
            ),
          ),
          Expanded(child: _buildBody(formatCurrency)),
        ],
      ),
    );
  }

  Widget _buildBody(NumberFormat formatCurrency) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_errorMessage!,
                style: const TextStyle(color: AppTheme.dangerColor)),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => reloadData(showLoading: true),
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      );
    }
    final items = _visibleEntries;
    if (items.isEmpty) {
      return const Center(
        child: Text('Belum ada riwayat pada tanggal ini.',
            style: TextStyle(color: AppTheme.textLightColor)),
      );
    }
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final entry = items[index];
        final tx = entry.transaction;
        final exp = entry.expense;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _HistoryTypeLabel(kind: entry.kind),
            const SizedBox(height: 4),
            if (tx != null)
              _HistoryListTile(
                transaction: tx,
                formatCurrency: formatCurrency,
                dateFormat: dateFormat,
                displayTable: _displayTable(tx),
                onReprint: () => _reprint(tx),
                onVoid: () => _openVoidDialog(tx),
              )
            else if (exp != null)
              _HistoryExpenseTile(
                expense: exp,
                formatCurrency: formatCurrency,
                dateFormat: dateFormat,
                onVoid: () => _voidExpense(exp),
              ),
          ],
        );
      },
    );
  }
}