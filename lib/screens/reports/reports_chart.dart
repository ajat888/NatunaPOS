part of '../reports_screen.dart';
import 'dart:math';

class _ReportsChart extends StatelessWidget {
  final List<Map<String, dynamic>> dailySales;
  const _ReportsChart({required this.dailySales});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.decimalPattern('id');
    
    int maxSales = 0;
    for (final d in dailySales) {
      final s = (d['sales'] as num).toInt();
      if (s > maxSales) maxSales = s;
    }
    if (maxSales == 0) maxSales = 1;

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
          const Row(
            children: [
              Icon(Icons.bar_chart, color: AppTheme.primaryColor, size: 18),
              SizedBox(width: 6),
              Text(
                'GRAFIK PENJUALAN',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: AppTheme.textLightColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 120,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: dailySales.map((d) {
                final dateStr = (d['date'] as String).split('-').last;
                final sales = (d['sales'] as num).toInt();
                final double ratio = sales / maxSales;
                final double barHeight = max(4.0, ratio * 100);

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Tooltip(
                          message: 'Tgl $dateStr: Rp ${fmt.format(sales)}',
                          child: Container(
                            height: barHeight,
                            decoration: BoxDecoration(
                              color: sales > 0 ? AppTheme.primaryColor : const Color(0xFFE2E8F0),
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          dateStr,
                          style: const TextStyle(fontSize: 9, color: AppTheme.textLightColor),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}