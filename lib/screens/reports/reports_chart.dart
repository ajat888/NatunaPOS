part of '../reports_screen.dart';

class _ReportsChart extends StatelessWidget {
  final List<Map<String, dynamic>> dailySales;
  final DateTime from;
  final DateTime to;

  const _ReportsChart({
    required this.dailySales, 
    required this.from, 
    required this.to,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.decimalPattern('id');
    
    // Map data dari DB untuk lookup cepat (key: yyyy-MM-dd)
    final Map<String, int> salesMap = {
      for (var d in dailySales) d['date'] as String: (d['sales'] as num).toInt()
    };

    // Generate semua tanggal dari `from` sampai `to`
    List<DateTime> days = [];
    DateTime current = DateTime(from.year, from.month, from.day);
    final end = DateTime(to.year, to.month, to.day);
    
    while (current.isBefore(end) || current.isAtSameMomentAs(end)) {
      days.add(current);
      current = current.add(const Duration(days: 1));
    }

    // Jika rentang terlalu panjang (> 15 hari), kita ambil 15 hari terakhir saja
    // agar grafik tidak terlalu padat di layar HP.
    bool isTrimmed = false;
    if (days.length > 15) {
      days = days.sublist(days.length - 15);
      isTrimmed = true;
    }

    // Cari nilai maksimal untuk menentukan tinggi bar
    int maxSales = 0;
    final List<Map<String, dynamic>> chartData = [];
    
    for (var day in days) {
      final dateStr = DateFormat('yyyy-MM-dd').format(day);
      final sales = salesMap[dateStr] ?? 0;
      if (sales > maxSales) maxSales = sales;
      
      chartData.add({
        'date': dateStr,
        'label': DateFormat('dd').format(day),
        'sales': sales,
      });
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
              if (isTrimmed)
                const Text(
                  '15 Hari Terakhir',
                  style: TextStyle(fontSize: 10, color: AppTheme.textLightColor),
                ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 120,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: chartData.map((d) {
                final sales = d['sales'] as int;
                final double ratio = sales / maxSales;
                
                final double rawHeight = ratio * 100;
                final double barHeight = rawHeight < 4.0 ? 4.0 : rawHeight;

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1.5),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Tooltip(
                          message: 'Tgl ${d['label']}: Rp ${fmt.format(sales)}',
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
                          d['label'] as String,
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