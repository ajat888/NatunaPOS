part of '../history_screen.dart';

class _HistoryExpenseTile extends StatelessWidget {
  final Expense expense;
  final NumberFormat formatCurrency;
  final DateFormat dateFormat;
  final VoidCallback onVoid;

  const _HistoryExpenseTile({
    required this.expense,
    required this.formatCurrency,
    required this.dateFormat,
    required this.onVoid,
  });

  @override
  Widget build(BuildContext context) {
    final exp = expense;
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        title: Row(
          children: [
            Expanded(
              child: Text(
                exp.itemName,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: AppTheme.textColor),
              ),
            ),
            Text(
              '- Rp ${formatCurrency.format(exp.amount)}',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: AppTheme.dangerColor),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${exp.categoryName} • ${dateFormat.format(exp.createdAt)} • oleh: ${exp.createdBy}',
                style: const TextStyle(
                    fontSize: 12, color: AppTheme.textLightColor),
              ),
              if (exp.description != null && exp.description!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    '"${exp.description}"',
                    style: const TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: AppTheme.textLightColor),
                  ),
                ),
            ],
          ),
        ),
        trailing: kIsWeb
            ? null
            : IconButton(
                icon: const Icon(Icons.cancel_outlined,
                    color: AppTheme.dangerColor, size: 20),
                onPressed: onVoid,
                tooltip: 'Void',
              ),
      ),
    );
  }
}