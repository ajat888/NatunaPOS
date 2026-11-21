part of '../history_screen.dart';

class _HistoryTypeLabel extends StatelessWidget {
  final HistoryKind kind;

  const _HistoryTypeLabel({required this.kind});

  @override
  Widget build(BuildContext context) {
    final isSale = kind == HistoryKind.sale;
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        isSale ? 'PENJUALAN' : 'PENGELUARAN',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.6,
          color: isSale ? AppTheme.primaryColor : AppTheme.dangerColor,
        ),
      ),
    );
  }
}