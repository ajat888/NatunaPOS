import 'report_service.dart';

class BreakEvenMath {
  BreakEvenMath._();

  static Map<String, dynamic> periodView({
    required int monthly,
    required ReportSummary summary,
  }) {
    final days = summary.to.difference(summary.from).inDays + 1;
    final daysInMonth = DateTime(summary.to.year, summary.to.month + 1, 0).day;
    final target = (monthly * days / daysInMonth).round();
    final contribution = summary.grossProfit - summary.totalExpenses;
    return <String, dynamic>{
      'hari_periode': days,
      'hari_dalam_bulan': daysInMonth,
      'target_periode': target,
      'kontribusi_periode': contribution,
      'sisa_biaya_periode': target - contribution,
    };
  }

  static Map<String, dynamic> remainingView({
    required int monthly,
    required ReportSummary mtd,
  }) {
    final remainingDays =
        DateTime(mtd.to.year, mtd.to.month + 1, 0).day - mtd.to.day;
    final gap = monthly - (mtd.grossProfit - mtd.totalExpenses);
    final marginRatio =
        mtd.totalSales > 0 ? mtd.grossProfit / mtd.totalSales : 0.0;
    final unknown = gap > 0 && marginRatio <= 0;
    final needed = gap > 0 && marginRatio > 0 ? gap / marginRatio : 0.0;
    final perDay = remainingDays > 0 ? needed / remainingDays : 0.0;
    final avgDaily = mtd.totalSales / mtd.to.day;
    return <String, dynamic>{
      'sisa_hari': remainingDays,
      'omzet_harian_dibutuhkan': unknown ? null : perDay.round(),
      'omzet_harian_rata_rata': avgDaily.round(),
    };
  }
}