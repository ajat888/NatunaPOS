part of '../history_screen.dart';

class _HistoryDateBar extends StatelessWidget {
  final DateTime date;
  final bool isToday;
  final VoidCallback onPrev;
  final VoidCallback? onNext;
  final VoidCallback onPick;

  const _HistoryDateBar({
    required this.date,
    required this.isToday,
    required this.onPrev,
    required this.onNext,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final dateText = DateFormat('dd/MM/yyyy').format(date);
    final label = isToday ? 'Hari ini • $dateText' : dateText;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            tooltip: 'Hari sebelumnya',
            onPressed: onPrev,
          ),
          Expanded(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: AppTheme.textColor),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.calendar_today, size: 20),
            tooltip: 'Pilih tanggal',
            onPressed: onPick,
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            tooltip: 'Hari berikutnya',
            onPressed: onNext,
          ),
        ],
      ),
    );
  }
}