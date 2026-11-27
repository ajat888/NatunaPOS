part of '../dashboard_screen.dart';

class _DashboardTargetCard extends StatelessWidget {
  final bool isLoading;
  final int monthlyFixedCost;
  final int contribution;
  final double marginRatio;

  const _DashboardTargetCard({
    required this.isLoading,
    required this.monthlyFixedCost,
    required this.contribution,
    required this.marginRatio,
  });

  @override
  Widget build(BuildContext context) {
    final formatCurrency = NumberFormat.decimalPattern('id');
    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final target =
        monthlyFixedCost > 0 ? (monthlyFixedCost / daysInMonth).round() : 0;
    final hasTarget = target > 0;
    final remaining = target - contribution;
    final covered = hasTarget && remaining <= 0;
    final progress =
        hasTarget ? (contribution / target).clamp(0.0, 1.0).toDouble() : 0.0;
    final accent = covered ? Colors.green.shade700 : AppTheme.primaryColor;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                covered ? Icons.verified_outlined : Icons.flag_outlined,
                size: 20,
                color: covered ? accent : AppTheme.textLightColor,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Target Biaya Tetap Hari Ini',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textLightColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (isLoading)
            const Text(
              '—',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: AppTheme.textColor,
              ),
            )
          else if (!hasTarget)
            const Text(
              'Biaya tetap bulanan belum diisi. Isi di Pengaturan agar target harian bisa dihitung.',
              style: TextStyle(fontSize: 14, color: AppTheme.textLightColor),
            )
          else ...[
            Text(
              'Rp ${formatCurrency.format(contribution)} / Rp ${formatCurrency.format(target)}',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: covered ? accent : AppTheme.textColor,
              ),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: const Color(0xFFE2E8F0),
                valueColor: AlwaysStoppedAnimation<Color>(accent),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              covered
                  ? 'Biaya tetap hari ini tertutup. Lebih Rp ${formatCurrency.format(-remaining)}.'
                  : 'Kurang Rp ${formatCurrency.format(remaining)} dari kontribusi hari ini.',
              style: TextStyle(
                fontSize: 13,
                color: covered ? accent : AppTheme.dangerColor,
              ),
            ),
            if (!covered && marginRatio > 0) ...[
              const SizedBox(height: 4),
              Text(
                'Perkiraan omzet tambahan yang dibutuhkan: Rp ${formatCurrency.format((remaining / marginRatio).round())}.',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.textLightColor,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}