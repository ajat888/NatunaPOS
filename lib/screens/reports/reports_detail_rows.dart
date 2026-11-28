part of '../reports_screen.dart';

Widget _buildProgressBar(ReportSummary summary) {
  final hpp = summary.totalHpp.clamp(0, summary.totalSales);
  final exp = summary.totalExpenses.clamp(0, summary.totalSales - hpp);
  final profit = summary.netProfit > 0
      ? summary.netProfit.clamp(0, summary.totalSales - hpp - exp)
      : 0;

  return Container(
    height: 10,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(5),
      color: const Color(0xFFE2E8F0),
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(5),
      child: Row(
        children: [
          if (hpp > 0)
            Expanded(
                flex: hpp,
                child: Container(color: AppTheme.dangerColor)),
          if (exp > 0)
            Expanded(
                flex: exp,
                child: Container(color: Colors.orange.shade800)),
          if (profit > 0)
            Expanded(
                flex: profit,
                child: Container(color: Colors.green.shade700)),
        ],
      ),
    ),
  );
}

Widget _row(
  String label,
  String value, {
  bool danger = false,
  bool bold = false,
  bool positive = false,
  VoidCallback? onInfo,
}) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Expanded(
        child: Row(
          children: [
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
                  color: danger ? AppTheme.dangerColor : AppTheme.textLightColor,
                ),
              ),
            ),
            if (onInfo != null) ...[
              const SizedBox(width: 4),
              InkWell(
                onTap: onInfo,
                borderRadius: BorderRadius.circular(16),
                child: const Padding(
                  padding: EdgeInsets.all(2),
                  child: Icon(
                    Icons.info_outline,
                    size: 14,
                    color: AppTheme.textLightColor,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      Text(
        value,
        style: TextStyle(
          fontSize: 13,
          fontWeight: bold ? FontWeight.bold : FontWeight.w600,
          color: danger
              ? AppTheme.dangerColor
              : (positive ? Colors.green.shade700 : AppTheme.textColor),
        ),
      ),
    ],
  );
}
