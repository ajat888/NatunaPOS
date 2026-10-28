// lib/screens/pos/pos_order_detail.dart
part of '../pos_screen.dart';

class _PosOrderDetailView extends StatelessWidget {
  final OpenOrder order;
  final VoidCallback onBack;
  final VoidCallback onAddMore;
  final VoidCallback onPay;
  final void Function(OpenOrderItem item, int delta) onAdjustQty;
  final Future<void> Function() onVoid;

  const _PosOrderDetailView({
    required this.order,
    required this.onBack,
    required this.onAddMore,
    required this.onPay,
    required this.onAdjustQty,
    required this.onVoid,
  });

  @override
  Widget build(BuildContext context) {
    final formatCurrency = NumberFormat.decimalPattern('id');
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: onBack),
        title: Text(order.label),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppTheme.dangerColor),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (c) => AlertDialog(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  title: const Text('Void Pesanan'),
                  content: Text('Hapus seluruh pesanan ${order.label}?'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(c, false),
                        child: const Text('BATAL')),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.dangerColor),
                      onPressed: () => Navigator.pop(c, true),
                      child: const Text('VOID'),
                    ),
                  ],
                ),
              );
              if (confirm == true) await onVoid();
            },
            tooltip: 'Void',
          ),
        ],
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: order.items.isEmpty
                ? const Center(
                    child: Text('Pesanan kosong.',
                        style: TextStyle(color: AppTheme.textLightColor)))
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: order.items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final item = order.items[i];
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceColor,
                          borderRadius: BorderRadius.circular(8),
                          border:
                              Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.productName,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.textColor)),
                                  const SizedBox(height: 2),
                                  Text(
                                      'Rp ${formatCurrency.format(item.price)} x ${item.qty}',
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: AppTheme.textLightColor)),
                                ],
                              ),
                            ),
                            Text('Rp ${formatCurrency.format(item.subtotal)}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textColor)),
                            const SizedBox(width: 12),
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline,
                                  color: AppTheme.dangerColor),
                              onPressed: () => onAdjustQty(item, -1),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline,
                                  color: AppTheme.primaryColor),
                              onPressed: () => onAdjustQty(item, 1),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          Container(
            width: 280,
            decoration: const BoxDecoration(
              color: AppTheme.surfaceColor,
              border: Border(left: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('Ringkasan',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textColor,
                              fontSize: 14)),
                      const SizedBox(height: 12),
                      _row('Total Item', '${order.itemCount}'),
                      const SizedBox(height: 6),
                      _row('Total',
                          'Rp ${formatCurrency.format(order.total)}',
                          highlight: true),
                    ],
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      OutlinedButton.icon(
                        onPressed: onAddMore,
                        icon: const Icon(Icons.add),
                        label: const Text('TAMBAH PESANAN'),
                        style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14)),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: onPay,
                        icon: const Icon(Icons.payments_outlined),
                        label: const Text('BAYAR'),
                        style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value, {bool highlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(
                color: AppTheme.textLightColor, fontSize: 13)),
        Text(value,
            style: TextStyle(
              fontWeight: highlight ? FontWeight.bold : FontWeight.w600,
              fontSize: highlight ? 16 : 13,
              color: highlight ? AppTheme.primaryColor : AppTheme.textColor,
            )),
      ],
    );
  }
}