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
    final size = Breakpoints.of(context);
    if (size.isCompact) return _buildCompact(context);
    return _buildWide(context, panelWidth: size.isExpanded ? 280 : 240);
  }

  // ---------- COMPACT (portrait HP) ----------

  Widget _buildCompact(BuildContext context) {
    return Stack(
      children: [
        SingleChildScrollView(
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
              _buildTableGrid(context, crossAxisCount: 5),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: onTapTakeAway,
                icon: const Icon(Icons.shopping_bag_outlined),
                label: const Text('TAKE AWAY'),
                style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 20)),
              ),
              const SizedBox(height: 96),
            ],
          ),
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton.extended(
            onPressed: () => _showOrdersSheet(context),
            icon: const Icon(Icons.receipt_long_outlined),
            label: Text('Pesanan (${openOrders.length})'),
            backgroundColor: AppTheme.primaryColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );
  }

  void _showOrdersSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.65,
          minChildSize: 0.35,
          maxChildSize: 0.95,
          builder: (_, scrollController) {
            return Column(
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Belum Bayar',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: AppTheme.textColor)),
                      Text('${openOrders.length}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryColor,
                              fontSize: 16)),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: _buildOrdersPanelContent(
                    scrollController: scrollController,
                    onTapAfterAction: () => Navigator.of(sheetContext).pop(),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ---------- WIDE (landscape / tablet) ----------

  Widget _buildWide(BuildContext context, {required double panelWidth}) {
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
                _buildTableGrid(context, crossAxisCount: 10),
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
          width: panelWidth,
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
                  border: Border(
                      bottom: BorderSide(color: Color(0xFFE2E8F0))),
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
              Expanded(child: _buildOrdersPanelContent()),
            ],
          ),
        ),
      ],
    );
  }

  // ---------- SHARED ----------

  Widget _buildTableGrid(BuildContext context,
      {required int crossAxisCount}) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
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
              color:
                  isOccupied ? AppTheme.primaryColor : AppTheme.surfaceColor,
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
    );
  }

  Widget _buildOrdersPanelContent({
    ScrollController? scrollController,
    VoidCallback? onTapAfterAction,
  }) {
    if (openOrders.isEmpty) {
      return const Center(
        child: Padding(
            padding: EdgeInsets.all(16),
            child: Text('Belum ada pesanan.',
                style: TextStyle(color: AppTheme.textLightColor),
                textAlign: TextAlign.center)),
      );
    }
    return ListView.separated(
      controller: scrollController,
      padding: const EdgeInsets.all(8),
      itemCount: openOrders.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final o = openOrders[i];
        return InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            onTapOpenOrder(o);
            onTapAfterAction?.call();
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.backgroundColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(o.label,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textColor,
                            fontSize: 13)),
                    Text('${o.itemCount} item',
                        style: const TextStyle(
                            color: AppTheme.textLightColor, fontSize: 11)),
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
                      onPressed: () {
                        onTapAfterAction?.call();
                        onTapPay(o);
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
    );
  }
}