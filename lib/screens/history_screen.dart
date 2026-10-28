// lib/screens/history_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/theme.dart';
import '../models/transaction.dart';
import '../services/supabase_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _service = SupabaseService();
  List<Transaction> _transactions = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Riwayat Transaksi'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _load,
              tooltip: 'Muat ulang'),
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
                          onPressed: _load, child: const Text('Coba Lagi')),
                    ],
                  ),
                )
              : _transactions.isEmpty
                  ? const Center(
                      child: Text(
                        'Belum ada riwayat transaksi.',
                        style: TextStyle(color: AppTheme.textLightColor),
                      ),
                    )
                  : _buildList(),
    );
  }

  Widget _buildList() {
    final formatCurrency = NumberFormat.decimalPattern('id');
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: _transactions.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final tx = _transactions[index];
        return Container(
          decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0))),
          child: Theme(
            data: Theme.of(context).copyWith(
              dividerColor: Colors.transparent,
              splashColor: Colors.transparent,
            ),
            child: ExpansionTile(
              tilePadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              childrenPadding:
                  const EdgeInsets.only(left: 16, right: 16, bottom: 8),
              title: Text(
                'Rp ${formatCurrency.format(tx.total)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: AppTheme.textColor,
                ),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '${_displayTable(tx)} • ${dateFormat.format(tx.createdAt)} • ${tx.itemCount} item',
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.textLightColor),
                ),
              ),
              children: [
                ...tx.items.map((item) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${item.productName}  ×${item.qty}',
                            style: const TextStyle(
                                fontSize: 13, color: AppTheme.textColor),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          'Rp ${formatCurrency.format(item.subtotal)}',
                          style: const TextStyle(
                              fontSize: 13,
                              color: AppTheme.textLightColor,
                              fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  );
                }),
                if (tx.cashReceived > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Tunai / Kembali',
                            style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.textLightColor)),
                        Text(
                          'Rp ${formatCurrency.format(tx.cashReceived)} / Rp ${formatCurrency.format(tx.changeAmount)}',
                          style: const TextStyle(
                              fontSize: 12, color: AppTheme.textLightColor),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}