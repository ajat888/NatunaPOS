part of '../reports_screen.dart';

double _marginPct(Map<String, dynamic> p) {
  final price = p['unit_price'] as int;
  final hpp = p['unit_hpp'] as int;
  return price > 0 ? (price - hpp) / price * 100 : 0;
}

class _ReportsMarginTable extends StatelessWidget {
  final List<Map<String, dynamic>> products;
  const _ReportsMarginTable({required this.products});

  @override
  Widget build(BuildContext context) {
    final rows = products.where((p) => (p['unit_price'] as int) > 0).toList()
      ..sort((a, b) => _marginPct(a).compareTo(_marginPct(b)));
    if (rows.isEmpty) return const SizedBox.shrink();

    final fmt = NumberFormat.decimalPattern('id');
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Margin per Menu',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppTheme.textColor,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Diurutkan dari margin terkecil. Menu di bawah 30% perlu dievaluasi sebelum diberi diskon.',
            style: TextStyle(fontSize: 11, color: AppTheme.textLightColor),
          ),
          const SizedBox(height: 12),
          ...rows.map((p) => _marginRow(p, fmt)),
        ],
      ),
    );
  }

  Widget _marginRow(Map<String, dynamic> p, NumberFormat fmt) {
    final price = p['unit_price'] as int;
    final hpp = p['unit_hpp'] as int;
    final margin = price - hpp;
    final pct = _marginPct(p);
    final tipis = pct < 30;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p['name'] as String,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textColor,
                  ),
                ),
                Text(
                  'Harga ${fmt.format(price)} · HPP ${fmt.format(hpp)}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textLightColor,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${fmt.format(margin)} (${pct.toStringAsFixed(0)}%)',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: tipis ? AppTheme.dangerColor : AppTheme.primaryColor,
            ),
          ),
        ],
      ),
    );
  }
}