part of '../closing_screen.dart';

class _ClosingConfirmationDialog extends StatelessWidget {
  final int totalSales;
  final int cashActual;
  final int cashDifference;

  const _ClosingConfirmationDialog({
    required this.totalSales,
    required this.cashActual,
    required this.cashDifference,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.decimalPattern('id');
    final screenW = MediaQuery.sizeOf(context).width;
    final contentW = screenW < 528 ? screenW - 88 : 400.0;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      title: const Row(
  children: [
    Icon(Icons.warning_amber_rounded, color: AppTheme.dangerColor),
    SizedBox(width: 8),
    Expanded(child: Text('Konfirmasi Closing')),
  ],
),
      content: SizedBox(
        width: contentW,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Yakin tutup buku hari ini? Aksi ini tidak bisa diubah setelah disimpan.',
              style: TextStyle(fontSize: 13, color: AppTheme.textColor),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.backgroundColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  _row('Total Penjualan', 'Rp ${fmt.format(totalSales)}'),
                  const SizedBox(height: 6),
                  _row('Cash Fisik', 'Rp ${fmt.format(cashActual)}'),
                  const SizedBox(height: 6),
                  _row(
                    'Selisih',
                    'Rp ${fmt.format(cashDifference)}',
                    danger: cashDifference < 0,
                    positive: cashDifference > 0,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('BATAL'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.dangerColor,
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('TUTUP BUKU'),
        ),
      ],
    );
  }

  Widget _row(
    String label,
    String value, {
    bool danger = false,
    bool positive = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 12, color: AppTheme.textLightColor)),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: danger
                ? AppTheme.dangerColor
                : (positive ? Colors.green.shade700 : AppTheme.textColor),
          ),
        ),
      ],
    );
  }
}