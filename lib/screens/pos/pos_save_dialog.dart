part of '../pos_screen.dart';

class _SaveOrderDialog extends StatelessWidget {
  final Map<int, int> cart;
  final List<Product> products;
  final String targetLabel;
  final int total;
  final int itemCount;

  const _SaveOrderDialog({
    required this.cart,
    required this.products,
    required this.targetLabel,
    required this.total,
    required this.itemCount,
  });

  @override
  Widget build(BuildContext context) {
    final formatCurrency = NumberFormat.decimalPattern('id');
    final items = <Widget>[];

    cart.forEach((id, qty) {
      Product? p;
      for (var item in products) {
        if (item.id == id) {
          p = item;
          break;
        }
      }
      if (p == null) return;

      items.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  '${p.name} x$qty',
                  style: const TextStyle(
                      fontSize: 13, color: AppTheme.textColor),
                ),
              ),
              Text(
                'Rp ${formatCurrency.format(p.price * qty)}',
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textColor),
              ),
            ],
          ),
        ),
      );
    });

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      title: const Text('Simpan Pesanan?'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (items.isNotEmpty)
              Container(
                constraints: const BoxConstraints(maxHeight: 200),
                decoration: BoxDecoration(
                  color: AppTheme.backgroundColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: ListView(
                  shrinkWrap: true,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  children: items,
                ),
              ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total Item',
                  style: TextStyle(
                      color: AppTheme.textLightColor, fontSize: 13),
                ),
                Text(
                  '$itemCount',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: AppTheme.textColor),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total',
                  style: TextStyle(
                      color: AppTheme.textLightColor, fontSize: 13),
                ),
                Text(
                  'Rp ${formatCurrency.format(total)}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppTheme.primaryColor),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Simpan pesanan ini ke $targetLabel?',
              style: const TextStyle(fontSize: 13, color: AppTheme.textColor),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('EDIT'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('YA'),
        ),
      ],
    );
  }
}