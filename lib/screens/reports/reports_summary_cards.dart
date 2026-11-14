part of '../reports_screen.dart';

class _ReportsSummaryCards extends StatelessWidget {
  final ReportSummary summary;
  const _ReportsSummaryCards({required this.summary});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.decimalPattern('id');
    final avgTx = summary.totalTransactions > 0 
        ? (summary.totalSales / summary.totalTransactions).round() 
        : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _summaryCard(
                'Total Penjualan',
                'Rp ${fmt.format(summary.totalSales)}',
                Icons.account_balance_wallet_outlined,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _summaryCard(
                'Transaksi',
                '${summary.totalTransactions}',
                Icons.receipt_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _summaryCard(
                'Pengeluaran',
                '- Rp ${fmt.format(summary.totalExpenses)}',
                Icons.money_off,
                danger: summary.totalExpenses > 0,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _summaryCard(
                'Laba Bersih',
                'Rp ${fmt.format(summary.netProfit)}',
                Icons.trending_up,
                danger: summary.netProfit < 0,
                positive: summary.netProfit >= 0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _detailsCard(context, fmt, avgTx),
      ],
    );
  }

  Widget _summaryCard(
    String title,
    String value,
    IconData icon, {
    bool danger = false,
    bool positive = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(
              icon,
              size: 16,
              color: danger ? AppTheme.dangerColor : AppTheme.textLightColor,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  color: danger ? AppTheme.dangerColor : AppTheme.textLightColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: danger
                  ? AppTheme.dangerColor
                  : (positive ? Colors.green.shade700 : AppTheme.textColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailsCard(BuildContext context, NumberFormat fmt, int avgTx) {
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
            children: [
              const Text(
                'DETAIL',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: AppTheme.textLightColor,
                ),
              ),
              const SizedBox(width: 4),
              InkWell(
                onTap: () => _showDetailInfo(context),
                borderRadius: BorderRadius.circular(16),
                child: const Padding(
                  padding: EdgeInsets.all(2.0),
                  child: Icon(
                    Icons.help_outline,
                    size: 16,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          
          _row('Total Item Terjual', '${summary.totalItems} item'),
          const SizedBox(height: 6),
          _row('Rata-rata / Transaksi', 'Rp ${fmt.format(avgTx)}'),
          const SizedBox(height: 6),
          const Divider(height: 16, color: Color(0xFFE2E8F0)),
          
          _row('Total HPP (Modal Bahan)', 'Rp ${fmt.format(summary.totalHpp)}'),
          const SizedBox(height: 6),
          _row('Laba Kotor', 'Rp ${fmt.format(summary.grossProfit)}'),
          const SizedBox(height: 6),

          if (summary.voidTransactionCount > 0) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Transaksi Dibatalkan',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.dangerColor,
                      ),
                    ),
                    Text(
                      '(Tidak masuk omzet)',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppTheme.textLightColor,
                      ),
                    ),
                  ],
                ),
                Text(
                  '${summary.voidTransactionCount} • Rp ${fmt.format(summary.totalVoidAmount)}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.dangerColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
          ],
          
          if (summary.voidOpenOrderCount > 0) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pesanan Dibatalkan',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.dangerColor,
                      ),
                    ),
                    Text(
                      '(Tidak masuk omzet)',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppTheme.textLightColor,
                      ),
                    ),
                  ],
                ),
                Text(
                  '${summary.voidOpenOrderCount} • Rp ${fmt.format(summary.totalVoidOpenOrderAmount)}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.dangerColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
          ],

          if (summary.voidTransactionCount == 0 && summary.voidOpenOrderCount == 0) ...[
            _row('Pembatalan', 'Tidak ada', danger: false),
            const SizedBox(height: 6),
          ],

          const Divider(height: 20, color: Color(0xFFE2E8F0)),
          _row(
            'Uang Kas (Penjualan Tunai)',
            'Rp ${fmt.format(summary.cashExpected)}',
            bold: true,
          ),
        ],
      ),
    );
  }

  void _showDetailInfo(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        title: const Text('Informasi Detail'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Total HPP (Modal Bahan)',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: AppTheme.textColor),
            ),
            SizedBox(height: 4),
            Text(
              'Total harga modal (HPP) dari seluruh produk yang terjual hari ini.',
              style:
                  TextStyle(fontSize: 12, color: AppTheme.textLightColor),
            ),
            SizedBox(height: 12),
            Text(
              'Laba Kotor',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: AppTheme.textColor),
            ),
            SizedBox(height: 4),
            Text(
              'Total Penjualan dikurangi Total HPP. Laba ini belum dipotong pengeluaran operasional (seperti listrik, gaji, dll).',
              style:
                  TextStyle(fontSize: 12, color: AppTheme.textLightColor),
            ),
            SizedBox(height: 12),
            Text(
              'Laba Bersih',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: AppTheme.textColor),
            ),
            SizedBox(height: 4),
            Text(
              'Laba Kotor dikurangi Pengeluaran. Ini adalah keuntungan sesungguhnya Anda.',
              style:
                  TextStyle(fontSize: 12, color: AppTheme.textLightColor),
            ),
            SizedBox(height: 12),
            Text(
              'Uang Kas (Penjualan Tunai)',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: AppTheme.textColor),
            ),
            SizedBox(height: 4),
            Text(
              'Uang tunai murni dari transaksi pelanggan. Belum dipotong pengeluaran (karena pengeluaran diasumsikan tidak diambil dari laci kasir).',
              style:
                  TextStyle(fontSize: 12, color: AppTheme.textLightColor),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('MENGERTI'),
          ),
        ],
      ),
    );
  }

  Widget _row(
    String label,
    String value, {
    bool danger = false,
    bool bold = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: danger ? AppTheme.dangerColor : AppTheme.textLightColor,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: bold ? FontWeight.bold : FontWeight.w600,
            color: danger ? AppTheme.dangerColor : AppTheme.textColor,
          ),
        ),
      ],
    );
  }
}