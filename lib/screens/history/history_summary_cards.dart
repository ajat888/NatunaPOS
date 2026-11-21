part of '../history_screen.dart';

class _HistorySummaryCards extends StatelessWidget {
  final int salesTotal;
  final int salesCount;
  final int expenseTotal;
  final int expenseCount;
  final NumberFormat formatCurrency;

  const _HistorySummaryCards({
    required this.salesTotal,
    required this.salesCount,
    required this.expenseTotal,
    required this.expenseCount,
    required this.formatCurrency,
  });

  @override
  Widget build(BuildContext context) {
    final net = salesTotal - expenseTotal;
    final salesCard = _SummaryCard(
      label: 'Penjualan',
      value: 'Rp ${formatCurrency.format(salesTotal)}',
      caption: '$salesCount transaksi',
      color: AppTheme.primaryColor,
    );
    final expenseCard = _SummaryCard(
      label: 'Pengeluaran',
      value: 'Rp ${formatCurrency.format(expenseTotal)}',
      caption: '$expenseCount pengeluaran',
      color: AppTheme.dangerColor,
    );
    final netCard = _SummaryCard(
      label: 'Selisih',
      value:
          '${net < 0 ? '- ' : ''}Rp ${formatCurrency.format(net.abs())}',
      caption: 'Penjualan - Pengeluaran',
      color: net < 0 ? AppTheme.dangerColor : AppTheme.primaryColor,
    );
    if (Breakpoints.of(context).isCompact) {
      return Column(
        children: [
          salesCard,
          const SizedBox(height: 8),
          expenseCard,
          const SizedBox(height: 8),
          netCard,
        ],
      );
    }
    return Row(
      children: [
        Expanded(child: salesCard),
        const SizedBox(width: 8),
        Expanded(child: expenseCard),
        const SizedBox(width: 8),
        Expanded(child: netCard),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final String caption;
  final Color color;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.caption,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 12, color: AppTheme.textLightColor)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(height: 2),
          Text(caption,
              style: const TextStyle(
                  fontSize: 11, color: AppTheme.textLightColor)),
        ],
      ),
    );
  }
}