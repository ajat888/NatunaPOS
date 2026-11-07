part of '../closing_screen.dart';

class _ClosingSummarySection extends StatelessWidget {
  final ReportSummary summary;
  final int pendingSync;

  const _ClosingSummarySection({
    required this.summary,
    required this.pendingSync,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.decimalPattern('id');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (pendingSync > 0)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.shade300),
            ),
            child: Row(
              children: [
                Icon(Icons.cloud_off,
                    size: 18, color: Colors.orange.shade800),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '⚠️ $pendingSync perubahan belum tersinkron ke server. Data tetap aman di HP.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange.shade900,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        Container(
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
                'RINGKASAN HARI INI',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: AppTheme.textLightColor,
                ),
              ),
              const SizedBox(height: 12),
              _grid(fmt),
            ],
          ),
        ),
      ],
    );
  }

  Widget _grid(NumberFormat fmt) {
    final items = <Widget>[
      _stat('Total Penjualan', 'Rp ${fmt.format(summary.totalSales)}',
          primary: true),
      _stat('Jumlah Transaksi', '${summary.totalTransactions}'),
      _stat('Total HPP', 'Rp ${fmt.format(summary.totalHpp)}'),
      _stat('Laba Kotor', 'Rp ${fmt.format(summary.grossProfit)}'),
      _stat('Pengeluaran', '- Rp ${fmt.format(summary.totalExpenses)}',
          danger: summary.totalExpenses > 0),
      _stat('Laba Bersih', 'Rp ${fmt.format(summary.netProfit)}',
          danger: summary.netProfit < 0,
          positive: summary.netProfit >= 0),
      _stat(
        'Void',
        '${summary.totalVoidCount} • Rp ${fmt.format(summary.totalVoidAmount + summary.totalVoidOpenOrderAmount)}',
        danger: summary.totalVoidCount > 0,
      ),
      _stat('Cash Seharusnya', 'Rp ${fmt.format(summary.cashExpected)}'),
    ];
    return Column(
      children: [
        for (var i = 0; i < items.length; i += 2)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: items[i]),
                const SizedBox(width: 8),
                Expanded(
                  child: i + 1 < items.length
                      ? items[i + 1]
                      : const SizedBox(),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _stat(
    String label,
    String value, {
    bool primary = false,
    bool danger = false,
    bool positive = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppTheme.textLightColor,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: danger
                ? AppTheme.dangerColor
                : (primary
                    ? AppTheme.primaryColor
                    : (positive
                        ? Colors.green.shade700
                        : AppTheme.textColor)),
          ),
        ),
      ],
    );
  }
}