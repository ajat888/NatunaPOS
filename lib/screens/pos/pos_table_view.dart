// lib/screens/pos/pos_table_view.dart
part of '../pos_screen.dart';

class _PosTablesView extends StatelessWidget {
  final List<OpenOrder> openOrders;
  final void Function(int tableNumber) onTapEmptyTable;
  final void Function(OpenOrder order) onTapOpenOrder;
  final VoidCallback onTapTakeAway;
  final void Function(OpenOrder order) onTapPay;

  const _PosTablesView({
    required this.openOrders,
    required this.onTapEmptyTable,
    required this.onTapOpenOrder,
    required this.onTapTakeAway,
    required this.onTapPay,
  });

  OpenOrder? _orderForTable(int n) {
    final key = 'M-${n.toString().padLeft(2, '0')}';
    for (final o in openOrders) {
      if (o.orderKey == key) return o;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 3,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Pilih Meja',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textColor)),
                const SizedBox(height: 12),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 10,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 1,
                  ),
                  itemCount: 70,
                  itemBuilder: (context, i) {
                    final n = i + 1;
                    final o = _orderForTable(n);
                    final isOccupied = o != null;
                    return InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () {
                        if (isOccupied) {
                          onTapOpenOrder(o);
                        } else {
                          onTapEmptyTable(n);
                        }
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: isOccupied
                              ? AppTheme.primaryColor
                              : AppTheme.surfaceColor,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: isOccupied
                                  ? AppTheme.primaryColor
                                  : const Color(0xFFE2E8F0)),
                        ),
                        child: Center(
                          child: Text('$n',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: isOccupied
                                      ? Colors.white
                                      : AppTheme.textColor)),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: onTapTakeAway,
                  icon: const Icon(Icons.shopping_bag_outlined),
                  label: const Text('TAKE AWAY'),
                  style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 20)),
                ),
              ],
            ),
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
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Belum Bayar',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textColor,
                            fontSize: 14)),
                    Text('${openOrders.length}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                            fontSize: 14)),
                  ],
                ),
              ),
              Expanded(
                child: openOrders.isEmpty
                    ? const Center(
                        child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Text('Belum ada pesanan.',
                                style: TextStyle(
                                    color: AppTheme.textLightColor),
                                textAlign: TextAlign.center)))
                    : ListView.separated(
                        padding: const EdgeInsets.all(8),
                        itemCount: openOrders.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          final o = openOrders[i];
                          return InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () => onTapOpenOrder(o),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppTheme.backgroundColor,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: const Color(0xFFE2E8F0)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(o.label,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: AppTheme.textColor,
                                              fontSize: 13)),
                                      Text('${o.itemCount} item',
                                          style: const TextStyle(
                                              color: AppTheme.textLightColor,
                                              fontSize: 11)),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                      'Rp ${NumberFormat.decimalPattern('id').format(o.total)}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.primaryColor,
                                          fontSize: 13)),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      OutlinedButton(
                                        onPressed: () => onTapPay(o),
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 16, vertical: 6),
                                          minimumSize: Size.zero,
                                          tapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                        ),
                                        child: const Text('BAYAR',
                                            style: TextStyle(fontSize: 11)),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}