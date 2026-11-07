part of '../closing_screen.dart';

class _AlreadyClosedView extends StatelessWidget {
  final DailyClosing closing;
  final NumberFormat formatter;

  const _AlreadyClosedView({
    required this.closing,
    required this.formatter,
  });

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('dd/MM/yyyy HH:mm');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.shade300),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle,
                    color: Colors.green.shade700, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sudah Closing',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Tanggal: ${closing.closingDate}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textLightColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _card(
            'DETAIL CLOSING',
            Column(
              children: [
                _row('Total Penjualan',
                    'Rp ${formatter.format(closing.totalSales)}'),
                _row('Jumlah Transaksi', '${closing.totalTransactions}'),
                _row('Total HPP', 'Rp ${formatter.format(closing.totalHpp)}'),
                _row('Pengeluaran',
                    'Rp ${formatter.format(closing.totalExpenses)}'),
                _row(
                  'Total Void',
                  '${closing.voidCount} • Rp ${formatter.format(closing.totalVoidAmount)}',
                  danger: closing.voidCount > 0,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _card(
            'CASH',
            Column(
              children: [
                _row('Cash Seharusnya',
                    'Rp ${formatter.format(closing.cashExpected)}'),
                _row(
                  'Cash Aktual',
                  'Rp ${formatter.format(closing.cashActual)}',
                  bold: true,
                ),
                _row(
                  'Selisih',
                  'Rp ${formatter.format(closing.cashDifference)}',
                  danger: closing.cashDifference < 0,
                  positive: closing.cashDifference > 0,
                  bold: true,
                ),
              ],
            ),
          ),
          if (closing.closingNote != null &&
              closing.closingNote!.isNotEmpty) ...[
            const SizedBox(height: 16),
            _card(
              'CATATAN',
              Text(
                closing.closingNote!,
                style: const TextStyle(
                    fontSize: 13, color: AppTheme.textColor),
              ),
            ),
          ],
          const SizedBox(height: 16),
          _card(
            'INFO',
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _row('Oleh', closing.closedBy),
                _row('Waktu', dateFmt.format(closing.closedAt)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ReportsScreen()),
              );
            },
            icon: const Icon(Icons.bar_chart_outlined),
            label: const Text('LIHAT LAPORAN'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _card(String title, Widget content) {
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
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: AppTheme.textLightColor,
            ),
          ),
          const SizedBox(height: 10),
          content,
        ],
      ),
    );
  }

  Widget _row(
    String label,
    String value, {
    bool bold = false,
    bool danger = false,
    bool positive = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 12, color: AppTheme.textLightColor)),
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
      ),
    );
  }
}