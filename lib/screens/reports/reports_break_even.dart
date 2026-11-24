part of '../reports_screen.dart';

class _ReportsBreakEvenCard extends StatelessWidget {
  final ReportSummary summary;
  const _ReportsBreakEvenCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: FixedCostSettings.instance.monthly,
      builder: (context, monthly, _) => _buildCard(context, monthly),
    );
  }

  Widget _buildCard(BuildContext context, int monthly) {
    final decoration = BoxDecoration(
      color: AppTheme.surfaceColor,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: const Color(0xFFE2E8F0)),
    );

    if (monthly <= 0) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: decoration,
        child: const Text(
          'Isi biaya tetap bulanan di Pengaturan untuk melihat titik impas.',
          style: TextStyle(fontSize: 13, color: AppTheme.textLightColor),
        ),
      );
    }

    final fmt = NumberFormat.decimalPattern('id');
    final days = summary.to.difference(summary.from).inDays + 1;
    final daysInMonth =
        DateUtils.getDaysInMonth(summary.to.year, summary.to.month);
    final target = (monthly * days / daysInMonth).round();
    final contribution = summary.grossProfit - summary.totalExpenses;
    final covered = (contribution / target).clamp(0.0, 1.0).toDouble();
    final reached = contribution >= target;
    final gap = target - contribution;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: decoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Titik Impas Biaya Tetap',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppTheme.textColor,
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: covered,
              minHeight: 10,
              backgroundColor: const Color(0xFFE2E8F0),
              color: reached ? Colors.green : AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${(covered * 100).toStringAsFixed(0)}% tertutup',
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textLightColor,
            ),
          ),
          const SizedBox(height: 12),
          _row('Target periode', 'Rp ${fmt.format(target)}'),
          _row(
            'Kontribusi (laba kotor − pengeluaran)',
            'Rp ${fmt.format(contribution)}',
            danger: contribution < 0,
          ),
          _row(
            reached ? 'Status' : 'Sisa untuk impas',
            reached ? 'Impas tercapai' : 'Rp ${fmt.format(gap)}',
            danger: !reached,
          ),
          const SizedBox(height: 8),
          Text(
            'Biaya tetap ${fmt.format(monthly)} per bulan dibagi proporsional: $days dari $daysInMonth hari.',
            style: const TextStyle(
              fontSize: 11,
              color: AppTheme.textLightColor,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Jika sewa, listrik, atau gaji sudah dicatat sebagai pengeluaran, sebaiknya tidak diisi lagi di pengaturan biaya tetap.',
            style: TextStyle(
              fontSize: 11,
              color: AppTheme.textLightColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value, {bool danger = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textLightColor,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: danger ? AppTheme.dangerColor : AppTheme.textColor,
            ),
          ),
        ],
      ),
    );
  }
}