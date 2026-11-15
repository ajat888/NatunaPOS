import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../../../widgets/common/thousand_formatter.dart';

class ReportsSummaryCards extends StatelessWidget {
  final int totalSales;
  final int totalExpenses;
  final int totalHpp;
  final int netProfit;
  final int totalTransactions;

  const ReportsSummaryCards({
    super.key,
    required this.totalSales,
    required this.totalExpenses,
    required this.totalHpp,
    required this.netProfit,
    required this.totalTransactions,
  });

  @override
  Widget build(BuildContext context) {
    final totalOut = totalExpenses + totalHpp;
    final isProfit = netProfit >= 0;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildMainCard(
                title: 'Uang Masuk',
                amount: totalSales,
                icon: Icons.account_balance_wallet_outlined,
                color: AppTheme.navy,
                subtitle: '$totalTransactions transaksi',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildMainCard(
                title: 'Uang Keluar',
                amount: totalOut,
                icon: Icons.shopping_cart_outlined,
                color: AppTheme.red,
                subtitle: 'Belanja + Operasional',
                isNegative: true,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMainCard(
                title: 'Sisa Bersih',
                amount: netProfit,
                icon: Icons.trending_up,
                color: isProfit ? AppTheme.green : AppTheme.red,
                subtitle: isProfit ? 'Laba' : 'Rugi',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMainCard({
    required String title,
    required int amount,
    required IconData icon,
    required Color color,
    required String subtitle,
    bool isNegative = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.greyBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppTheme.greyText),
              const SizedBox(width: 6),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.greyText,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${isNegative ? "- " : ""}Rp ${ThousandFormatter.format(amount)}',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 11, color: AppTheme.greyText),
          ),
        ],
      ),
    );
  }
}