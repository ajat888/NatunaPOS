part of '../reports_screen.dart';

class _ReportsSummaryCards extends StatelessWidget {
  final ReportSummary summary;
  const _ReportsSummaryCards({required this.summary});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.decimalPattern('id');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Baris 1: Total Penjualan & Transaksi
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
        // Baris 2: Pengeluaran & Laba Bersih
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
    'Rp ${fmt.format(summary.totalSales - summary.totalExpenses)}',
    Icons.trending_up,
    danger: (summary.totalSales - summary.totalExpenses) < 0,
    positive: (summary.totalSales - summary.totalExpenses) >= 0,
  ),
),
          ],
        ),
        const SizedBox(height: 16),
        _detailsCard(fmt),
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

Widget _detailsCard(NumberFormat fmt) {
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
          'DETAIL',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
            color: AppTheme.textLightColor,
          ),
        ),
        const SizedBox(height: 10),
        
        if (summary.voidTransactionCount > 0) ...[
          _row(
            'Transaksi Dibatalkan',
            '${summary.voidTransactionCount} • Rp ${fmt.format(summary.totalVoidAmount)}',
            danger: true,
          ),
          const SizedBox(height: 6),
        ],
        
        if (summary.voidOpenOrderCount > 0) ...[
          _row(
            'Pesanan Dibatalkan',
            '${summary.voidOpenOrderCount} • Rp ${fmt.format(summary.totalVoidOpenOrderAmount)}',
            danger: true,
          ),
          const SizedBox(height: 6),
        ],

        if (summary.voidTransactionCount == 0 && summary.voidOpenOrderCount == 0) ...[
          _row(
            'Pembatalan',
            'Tidak ada',
            danger: false,
          ),
          const SizedBox(height: 6),
        ],

        const Divider(height: 20, color: Color(0xFFE2E8F0)),
        _row(
          'Cash Seharusnya',
          'Rp ${fmt.format(summary.cashExpected)}',
          bold: true,
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
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: danger ? AppTheme.dangerColor : AppTheme.textLightColor,
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