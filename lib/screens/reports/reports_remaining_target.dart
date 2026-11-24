part of '../reports_screen.dart';

class _ReportsRemainingTarget extends StatelessWidget {
  final ReportSummary summary;
  const _ReportsRemainingTarget({required this.summary});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    if (summary.to.year != now.year || summary.to.month != now.month) {
      return const SizedBox.shrink();
    }
    return ValueListenableBuilder<int>(
      valueListenable: FixedCostSettings.instance.monthly,
      builder: (context, monthly, _) {
        if (monthly <= 0) return const SizedBox.shrink();
        return FutureBuilder<ReportSummary>(
          future: _loadMonthToDate(),
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const SizedBox.shrink();
            }
            final mtd = snap.data;
            if (snap.hasError || mtd == null) return const SizedBox.shrink();
            return _buildCard(context, monthly, mtd);
          },
        );
      },
    );
  }

  Future<ReportSummary> _loadMonthToDate() {
    final to = summary.to;
    final from = DateTime(to.year, to.month, 1);
    return ReportService.instance.buildReport(from: from, to: to);
  }

  Widget _buildCard(BuildContext context, int monthly, ReportSummary mtd) {
    final fmt = NumberFormat.decimalPattern('id');
    final daysInMonth =
        DateUtils.getDaysInMonth(summary.to.year, summary.to.month);
    final remainingDays = daysInMonth - summary.to.day;
    final mtdContribution = mtd.grossProfit - mtd.totalExpenses;
    final gap = monthly - mtdContribution;
    final marginRatio =
        mtd.totalSales > 0 ? mtd.grossProfit / mtd.totalSales : 0.0;
    final neededOmzet =
        gap > 0 && marginRatio > 0 ? gap / marginRatio : 0.0;
    final perDayNeeded = remainingDays > 0 ? neededOmzet / remainingDays : 0.0;
    final avgDaily = mtd.totalSales / summary.to.day;

    final decoration = BoxDecoration(
      color: AppTheme.surfaceColor,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: const Color(0xFFE2E8F0)),
    );

    if (gap <= 0) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: decoration,
        child: const Text(
          'Titik impas bulan ini sudah tercapai.',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Colors.green,
          ),
        ),
      );
    }

    if (remainingDays <= 0) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: decoration,
        child: const Text(
          'Tidak ada sisa hari di bulan ini.',
          style: TextStyle(fontSize: 13, color: AppTheme.textLightColor),
        ),
      );
    }

    if (gap > 0 && marginRatio <= 0) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: decoration,
        child: Text(
          mtd.totalSales <= 0
              ? 'Belum bisa dihitung: belum ada penjualan bulan ini'
              : 'Belum bisa dihitung: margin kotor bulan ini nol atau minus',
          style: const TextStyle(fontSize: 13, color: AppTheme.textLightColor),
        ),
      );
    }

    final paceOk = avgDaily >= perDayNeeded;
    final paceGap = perDayNeeded - avgDaily;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: decoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Target Sisa Bulan Ini',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppTheme.textColor,
            ),
          ),
          const SizedBox(height: 12),
          _tgtRow('Sisa hari', '$remainingDays hari'),
          _tgtRow('Sisa biaya tetap yang belum tertutup',
              'Rp ${fmt.format(gap)}'),
          _tgtRow('Total omzet harian yang dibutuhkan (sisa hari)',
              'Rp ${fmt.format(perDayNeeded.round())}'),
          _tgtRow('Rata-rata omzet harian (total) bulan ini',
              'Rp ${fmt.format(avgDaily.round())}'),
          const SizedBox(height: 8),
          Text(
            paceOk
                ? 'Pace saat ini sudah cukup untuk impas.'
                : 'Pace kurang Rp ${fmt.format(paceGap.round())} per hari.',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: paceOk ? Colors.green : AppTheme.dangerColor,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Perkiraan: omzet dibagi margin kotor bulan berjalan, dengan pengeluaran dianggap tertutup dari margin itu.',
            style: TextStyle(fontSize: 11, color: AppTheme.textLightColor),
          ),
        ],
      ),
    );
  }
}

Widget _tgtRow(String label, String value) {
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
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppTheme.textColor,
          ),
        ),
      ],
    ),
  );
}