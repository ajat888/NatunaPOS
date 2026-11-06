part of '../pos_screen.dart';

class _PosSplitView extends StatefulWidget {
  final OpenOrder order;
  final VoidCallback onBack;
  final Future<void> Function(Map<int, int> selection) onPay;

  const _PosSplitView({
    required this.order,
    required this.onBack,
    required this.onPay,
  });

  @override
  State<_PosSplitView> createState() => _PosSplitViewState();
}

class _PosSplitViewState extends State<_PosSplitView> {
  final Map<int, int> _selected = {};

  int _qtyFor(OpenOrderItem item) => _selected[item.id] ?? 0;

  void _setQty(OpenOrderItem item, int qty) {
    setState(() {
      final clamped = qty.clamp(0, item.qty);
      if (clamped <= 0) {
        _selected.remove(item.id);
      } else {
        _selected[item.id] = clamped;
      }
    });
  }

  void _toggle(OpenOrderItem item) {
    final current = _qtyFor(item);
    if (current == 0) {
      _setQty(item, item.qty);
    } else {
      _setQty(item, 0);
    }
  }

  int get _totalQty => _selected.values.fold(0, (a, b) => a + b);

  int get _subtotal {
    int total = 0;
    for (final item in widget.order.items) {
      final qty = _qtyFor(item);
      if (qty > 0) total += item.price * qty;
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.decimalPattern('id');
    final size = Breakpoints.of(context);
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onBack,
        ),
        title: Text('Split ${widget.order.label}'),
        automaticallyImplyLeading: false,
      ),
      body: size.isCompact ? _buildCompact(fmt) : _buildWide(fmt),
    );
  }

  Widget _buildWide(NumberFormat fmt) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: _buildItemsList(fmt)),
        Container(
          width: 280,
          decoration: const BoxDecoration(
            color: AppTheme.surfaceColor,
            border: Border(left: BorderSide(color: Color(0xFFE2E8F0))),
          ),
          child: _buildSummaryPanel(fmt),
        ),
      ],
    );
  }

  Widget _buildCompact(NumberFormat fmt) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: _buildItemsList(fmt)),
        Container(
          decoration: const BoxDecoration(
            color: AppTheme.surfaceColor,
            border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
          ),
          child: SafeArea(top: false, child: _buildSummaryPanel(fmt)),
        ),
      ],
    );
  }

  Widget _buildItemsList(NumberFormat fmt) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: widget.order.items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) => _buildItemCard(widget.order.items[i], fmt),
    );
  }

  Widget _buildItemCard(OpenOrderItem item, NumberFormat fmt) {
    final qty = _qtyFor(item);
    final selected = qty > 0;
    return InkWell(
      onTap: () => _toggle(item),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.primaryColor.withOpacity(0.08)
              : AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? AppTheme.primaryColor : const Color(0xFFE2E8F0),
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.productName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Rp ${fmt.format(item.price)} × ${item.qty}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textLightColor,
                    ),
                  ),
                  if (selected) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Dipilih: $qty × Rp ${fmt.format(item.price)} = Rp ${fmt.format(item.price * qty)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (item.qty > 1 || selected) ...[
              const SizedBox(width: 8),
              _buildQtyControls(item, qty),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildQtyControls(OpenOrderItem item, int qty) {
    return Column(
      children: [
        if (qty > 0)
          IconButton(
            icon: const Icon(Icons.remove_circle_outline,
                color: AppTheme.dangerColor, size: 24),
            onPressed: () => _setQty(item, qty - 1),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        if (qty > 0)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              '$qty',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
            ),
          ),
        if (qty < item.qty)
          IconButton(
            icon: const Icon(Icons.add_circle,
                color: AppTheme.primaryColor, size: 24),
            onPressed: () => _setQty(item, qty + 1),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
      ],
    );
  }

  Widget _buildSummaryPanel(NumberFormat fmt) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$_totalQty item dipilih',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.textLightColor,
                ),
              ),
              Text(
                'dari ${widget.order.itemCount} item',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textLightColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Subtotal',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: AppTheme.textColor,
                ),
              ),
              Text(
                'Rp ${fmt.format(_subtotal)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  color: AppTheme.primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'PPN & diskon dihitung saat pembayaran',
            style: TextStyle(
              fontSize: 11,
              color: AppTheme.textLightColor,
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _totalQty > 0
                ? () => widget.onPay(Map.from(_selected))
                : null,
            icon: const Icon(Icons.payments_outlined),
            label: Text('BAYAR ($_totalQty item)'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ],
      ),
    );
  }
}