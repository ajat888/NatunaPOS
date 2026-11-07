part of '../history_screen.dart';

class _HistoryListTile extends StatelessWidget {
  final Transaction transaction;
  final NumberFormat formatCurrency;
  final DateFormat dateFormat;
  final String displayTable;
  final VoidCallback onReprint;
  final VoidCallback onVoid;

  const _HistoryListTile({
    required this.transaction,
    required this.formatCurrency,
    required this.dateFormat,
    required this.displayTable,
    required this.onReprint,
    required this.onVoid,
  });

  @override
  Widget build(BuildContext context) {
    final tx = transaction;
    return Container(
      decoration: BoxDecoration(
        color: tx.isVoided ? Colors.grey.shade50 : AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          splashColor: Colors.transparent,
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding:
              const EdgeInsets.only(left: 16, right: 16, bottom: 8),
          title: Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        'Rp ${formatCurrency.format(tx.total)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: tx.isVoided
                              ? AppTheme.textLightColor
                              : AppTheme.textColor,
                          decoration: tx.isVoided
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                    ),
                    if (tx.isVoided) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.dangerColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'VOID',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.print,
                  size: 20,
                  color: tx.isVoided
                      ? AppTheme.textLightColor
                      : AppTheme.primaryColor,
                ),
                onPressed: onReprint,
                tooltip: tx.isVoided ? 'Cetak Ulang (VOID)' : 'Cetak Ulang',
              ),
              if (!tx.isVoided)
                IconButton(
                  icon: const Icon(Icons.cancel_outlined,
                      size: 20, color: AppTheme.dangerColor),
                  onPressed: onVoid,
                  tooltip: 'Void',
                ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '$displayTable • ${dateFormat.format(tx.createdAt)} • ${tx.itemCount} item',
              style: const TextStyle(
                  fontSize: 12, color: AppTheme.textLightColor),
            ),
          ),
          children: [
            ...tx.items.map((item) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${item.productName}  ×${item.qty}',
                        style: const TextStyle(
                            fontSize: 13, color: AppTheme.textColor),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      'Rp ${formatCurrency.format(item.subtotal)}',
                      style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.textLightColor,
                          fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              );
            }),
            if (tx.cashReceived > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Tunai / Kembali',
                        style: TextStyle(
                            fontSize: 12, color: AppTheme.textLightColor)),
                    Text(
                      'Rp ${formatCurrency.format(tx.cashReceived)} / Rp ${formatCurrency.format(tx.changeAmount)}',
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.textLightColor),
                    ),
                  ],
                ),
              ),
            if (tx.isVoided) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.dangerColor.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Void oleh: ${tx.voidedBy ?? '-'}',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.dangerColor),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Alasan: ${tx.voidReason ?? '-'}',
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.textLightColor),
                    ),
                    if (tx.voidedAt != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Waktu: ${dateFormat.format(tx.voidedAt!)}',
                        style: const TextStyle(
                            fontSize: 11, color: AppTheme.textLightColor),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}