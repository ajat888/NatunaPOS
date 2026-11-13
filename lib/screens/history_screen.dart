import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/theme.dart';
import '../models/transaction.dart';
import '../services/supabase_service.dart';
import '../services/printer_service.dart';
import '../widgets/common/main_menu_scope.dart';
import 'voided_open_orders_screen.dart';

part 'history/history_list_tile.dart';
part 'history/void_dialog.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => HistoryScreenState();
}

class HistoryScreenState extends State<HistoryScreen> {
  final _service = SupabaseService();
  List<Transaction> _transactions = [];
  bool _isLoading = true;
  bool _showVoided = true;
  String? _errorMessage;

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
    final txs = await _service.getLocalTransactions();
    if (!mounted) return;
    setState(() {
      _transactions = txs;
      _isLoading = false;
    });
  } catch (e) {
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _errorMessage = 'Gagal memuat riwayat transaksi.';
    });
  }
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
    if (tx.isVoided) return;
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
      await reloadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Gagal void: ${e.toString().replaceAll('Exception: ', '')}'),
          backgroundColor: AppTheme.dangerColor,
        ),
      );
    }
  }

  void _openVoidedOpenOrders() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const VoidedOpenOrdersScreen()),
    );
  }

  List<Transaction> get _visibleTransactions {
    if (_showVoided) return _transactions;
    return _transactions.where((tx) => !tx.isVoided).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          tooltip: 'Menu',
          onPressed: () => MainMenuScope.of(context)?.openMenu(),
        ),
        title: const Text('Riwayat Transaksi'),
        actions: [
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_errorMessage!,
                          style: const TextStyle(color: AppTheme.dangerColor)),
                      const SizedBox(height: 16),
TextButton(
    onPressed: () => reloadData(showLoading: true),
    child: const Text('Coba Lagi')),
                    ],
                  ),
                )
              : _visibleTransactions.isEmpty
                  ? const Center(
                      child: Text('Belum ada riwayat transaksi.',
                          style: TextStyle(color: AppTheme.textLightColor)),
                    )
                  : _buildList(),
    );
  }

  Widget _buildList() {
    final formatCurrency = NumberFormat.decimalPattern('id');
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    final items = _visibleTransactions;
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final tx = items[index];
        return _HistoryListTile(
          transaction: tx,
          formatCurrency: formatCurrency,
          dateFormat: dateFormat,
          displayTable: _displayTable(tx),
          onReprint: () => _reprint(tx),
          onVoid: () => _openVoidDialog(tx),
        );
      },
    );
  }
}