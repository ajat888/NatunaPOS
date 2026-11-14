part of '../reports_screen.dart';

class _ReportsTopProducts extends StatelessWidget {
  final List<Map<String, dynamic>> topProducts;
  const _ReportsTopProducts({required this.topProducts});

  @override
  Widget build(BuildContext context) {
    if (topProducts.isEmpty) return const SizedBox.shrink();
    
    final fmt = NumberFormat.decimalPattern('id');
    final top3 = topProducts.take(3).toList();

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
          // PENAMBAHAN CONST DI SINI
          const Row(
            children: [
              Icon(Icons.star, color: Colors.amber, size: 18),
              SizedBox(width: 6),
              Text(
                'MENU TERLARIS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: AppTheme.textLightColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...List.generate(top3.length, (index) {
            final p = top3[index];
            final medali = index == 0 ? '🥇' : (index == 1 ? '🥈' : '🥉');
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Text(medali, style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p['name'] as String,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Omzet: Rp ${fmt.format(p['revenue'])}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.textLightColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${p['qty_sold']} porsi',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}