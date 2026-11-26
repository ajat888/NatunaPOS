import 'package:flutter/material.dart';
import '../../core/local_db.dart';
import '../../core/theme.dart';

const Map<String, String> _rejectedLabels = {
  'products': 'Produk',
  'categories': 'Kategori',
  'transactions': 'Transaksi',
};

int _rejectedTotal(Map<String, int> counts) =>
    counts.values.fold<int>(0, (a, b) => a + b);

String _rejectedBreakdown(Map<String, int> counts) {
  final lines = <String>[];
  for (final entry in counts.entries) {
    if (entry.value > 0) {
      lines.add('• ${_rejectedLabels[entry.key] ?? entry.key}: ${entry.value}');
    }
  }
  return lines.join('\n');
}

Future<void> showRejectedSyncDialog(BuildContext context) async {
  final counts = await LocalDb.instance.countRejectedSync();
  if (!context.mounted) return;
  final total = _rejectedTotal(counts);
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      title: const Row(
        children: [
          Icon(Icons.report_outlined, color: AppTheme.dangerColor),
          SizedBox(width: 8),
          Expanded(child: Text('Data Ditolak Server')),
        ],
      ),
      content: Text(
        total == 0
            ? 'Tidak ada data yang ditolak server.'
            : 'Data berikut ditolak server sehingga tidak bisa tersinkron. '
                'Data tetap tersimpan di HP ini.\n\n'
                '${_rejectedBreakdown(counts)}',
        style: const TextStyle(fontSize: 13, color: AppTheme.textColor),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('TUTUP'),
        ),
      ],
    ),
  );
}

Future<bool> confirmRejectedLogout(BuildContext context) async {
  final counts = await LocalDb.instance.countRejectedSync();
  final total = _rejectedTotal(counts);
  if (total == 0) return true;
  if (!context.mounted) return false;
  final confirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      title: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: AppTheme.dangerColor),
          SizedBox(width: 8),
          Expanded(child: Text('Data Ditolak Server')),
        ],
      ),
      content: Text(
        'Ada $total data yang ditolak server dan tidak bisa terkirim:\n\n'
        '${_rejectedBreakdown(counts)}\n\n'
        'Jika Anda logout, data ini akan hilang permanen dari HP ini.',
        style: const TextStyle(fontSize: 13, color: AppTheme.textColor),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('BATAL'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.dangerColor,
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('TETAP LOGOUT'),
        ),
      ],
    ),
  );
  return confirmed == true;
}