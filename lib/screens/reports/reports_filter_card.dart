part of '../reports_screen.dart';

class _ReportsFilterCard extends StatelessWidget {
  final DateTime from;
  final DateTime to;
  final ReportPreset preset;
  final void Function(ReportPreset) onPreset;
  final VoidCallback onPickFrom;
  final VoidCallback onPickTo;

  const _ReportsFilterCard({
    required this.from,
    required this.to,
    required this.preset,
    required this.onPreset,
    required this.onPickFrom,
    required this.onPickTo,
  });

  String _fmt(DateTime d) => DateFormat('dd/MM/yyyy').format(d);

  @override
  Widget build(BuildContext context) {
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
          Row(
            children: [
              const Icon(Icons.date_range,
                  size: 18, color: AppTheme.primaryColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${_fmt(from)} — ${_fmt(to)}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip('Hari Ini', ReportPreset.today),
              _chip('Kemarin', ReportPreset.yesterday),
              _chip('7 Hari', ReportPreset.last7),
              _chip('30 Hari', ReportPreset.last30),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onPickFrom,
                  icon: const Icon(Icons.calendar_today, size: 14),
                  label: Text(
                    _fmt(from),
                    style: const TextStyle(fontSize: 12),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onPickTo,
                  icon: const Icon(Icons.calendar_today, size: 14),
                  label: Text(
                    _fmt(to),
                    style: const TextStyle(fontSize: 12),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, ReportPreset p) {
    final selected = preset == p;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onPreset(p),
    );
  }
}