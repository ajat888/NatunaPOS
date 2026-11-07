import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/theme.dart';
import '../models/voided_open_order.dart';
import '../services/supabase_service.dart';

class VoidedOpenOrdersScreen extends StatefulWidget {
  const VoidedOpenOrdersScreen({super.key});

  @override
  State<VoidedOpenOrdersScreen> createState() => _VoidedOpenOrdersScreenState();
}

class _VoidedOpenOrdersScreenState extends State<VoidedOpenOrdersScreen> {
  final _service = SupabaseService();
  List<VoidedOpenOrder> _items = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }
    try {
      final list = await _service.getLocalVoidedOpenOrders();
      if (!mounted) return;
      setState(() {
        _items = list;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Gagal memuat data void.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Void Open Order'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Muat ulang',
            onPressed: _load,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_error!,
                          style: const TextStyle(color: AppTheme.dangerColor)),
                      const SizedBox(height: 16),
                      TextButton(
                          onPressed: _load, child: const Text('Coba Lagi')),
                    ],
                  ),
                )
              : _items.isEmpty
                  ? const Center(
                      child: Text('Belum ada pesanan yang di-void.',
                          style: TextStyle(color: AppTheme.textLightColor)),
                    )
                  : _buildList(),
    );
  }

  Widget _buildList() {
    final fmt = NumberFormat.decimalPattern('id');
    final dateFmt = DateFormat('dd/MM/yyyy HH:mm');
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: _items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final v = _items[index];
        return Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
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
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Rp ${fmt.format(v.subtotal)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppTheme.textColor,
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.dangerColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'VOID',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '${v.label} • ${v.itemCount} item • ${dateFmt.format(v.voidedAt)}',
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.textLightColor),
                ),
              ),
              children: [
                ...v.items.map((it) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${it.productName}  ×${it.qty}',
                              style: const TextStyle(
                                  fontSize: 13, color: AppTheme.textColor),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            'Rp ${fmt.format(it.subtotal)}',
                            style: const TextStyle(
                                fontSize: 13,
                                color: AppTheme.textLightColor,
                                fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    )),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.dangerColor.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Void oleh: ${v.voidedBy}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.dangerColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Alasan: ${v.voidReason}',
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.textLightColor),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Waktu: ${dateFmt.format(v.voidedAt)}',
                        style: const TextStyle(
                            fontSize: 11, color: AppTheme.textLightColor),
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