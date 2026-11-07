part of '../reports_screen.dart';

class _ReportsSummaryCards extends StatelessWidget {
  final ReportSummary summary;
  const _ReportsSummaryCards({required this.summary});

  @override
  Widget build(BuildContext context) {
    final size = Breakpoints.of(context);
    final isCompact = size.isCompact;
    final fmt = NumberFormat.decimalPattern('id');

    final cards = <Widget>[
      _summaryCard(
        'Total Penjualan',
        'Rp ${fmt.format(summary.totalSales)}',
        Icons.account_balance_wallet_outlined,
      ),
      _summaryCard(
        'Transaksi',
        '${summary.totalTransactions}',
        Icons.receipt_outlined,
      ),
      _summaryCard(
        'Pengeluaran',
        '- Rp ${fmt.format(summary.totalExpenses)}',
        Icons.money_off,
        danger: summary.totalExpenses > 0,
      ),
      _summaryCard(
        'Laba Bersih',
        'Rp ${fmt.format(summary.netProfit)}',
        Icons.trending_up,
        danger: summary.netProfit < 0,
        positive: summary.netProfit >= 0,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isCompact) ...[
          for (var i = 0; i < cards.length; i++) ...[
            cards[i],
            if (i < cards.length - 1) const SizedBox(height: 8),
          ],
        ] else ...[
          Row(children: [
            Expanded(child: cards[0]),
            const SizedBox(width: 8),
            Expanded(child: cards[1]),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: cards[2]),
            const SizedBox(width: 8),
            Expanded(child: cards[3]),
          ]),
        ],
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
      padding: const EdgeInsets.all(16),
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
              size: 18,
              color: danger ? AppTheme.dangerColor : AppTheme.textLightColor,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color:
                      danger ? AppTheme.dangerColor : AppTheme.textLightColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
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
          _row('Total HPP', 'Rp ${fmt.format(summary.totalHpp)}'),
          const SizedBox(height: 6),
          _row(
            'Laba Kotor',
            'Rp ${fmt.format(summary.grossProfit)}',
            highlight: true,
          ),
          const Divider(height: 20, color: Color(0xFFE2E8F0)),
          _row(
            'Void Transaksi',
            '${summary.voidTransactionCount} • Rp ${fmt.format(summary.totalVoidAmount)}',
            danger: summary.voidTransactionCount > 0,
          ),
          const SizedBox(height: 6),
          _row(
            'Void Open Order',
            '${summary.voidOpenOrderCount} • Rp ${fmt.format(summary.totalVoidOpenOrderAmount)}',
            danger: summary.voidOpenOrderCount > 0,
          ),
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
    bool highlight = false,
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
            fontWeight: bold || highlight ? FontWeight.bold : FontWeight.w600,
            color: danger
                ? AppTheme.dangerColor
                : (highlight ? AppTheme.primaryColor : AppTheme.textColor),
          ),
        ),
      ],
    );
  }
}