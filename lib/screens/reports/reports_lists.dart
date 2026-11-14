part of '../reports_screen.dart';

class _ReportsLists extends StatelessWidget {
  final ReportSummary summary;
  const _ReportsLists({required this.summary});

  @override
  Widget build(BuildContext context) {
    final hasAny =
        summary.transactions.isNotEmpty || summary.expenses.isNotEmpty;
    if (!hasAny) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Center(
          child: Text(
            'Tidak ada transaksi di rentang ini.',
            style: TextStyle(color: AppTheme.textLightColor),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (summary.transactions.isNotEmpty) _transactionsCard(context),
        if (summary.transactions.isNotEmpty && summary.expenses.isNotEmpty)
          const SizedBox(height: 16),
        if (summary.expenses.isNotEmpty) _expensesCard(context),
      ],
    );
  }

  Widget _transactionsCard(BuildContext context) {
    final fmt = NumberFormat.decimalPattern('id');
    final dateFmt = DateFormat('dd/MM/yyyy HH:mm');
    final items = summary.transactions.take(100).toList();
    
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
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
          title: Text(
            'Transaksi (${summary.transactions.length})',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.textColor,
            ),
          ),
          childrenPadding: const EdgeInsets.only(bottom: 8),
          children: [
            for (final tx in items) _transactionTile(context, tx, fmt, dateFmt),
          ],
        ),
      ),
    );
  }

  Widget _transactionTile(
    BuildContext context,
    Transaction tx,
    NumberFormat fmt,
    DateFormat dateFmt,
  ) {
    String itemSummary = tx.items.take(2).map((i) => '${i.qty}x ${i.productName}').join(', ');
    if (tx.items.length > 2) itemSummary += ', ...';

    return Theme(
      data: Theme.of(context).copyWith(
        dividerColor: Colors.transparent,
        splashColor: Colors.transparent,
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
        childrenPadding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
        shape: const Border(),
        collapsedShape: const Border(),
        title: Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      'Rp ${fmt.format(tx.total)}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
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
                    const SizedBox(width: 6),
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
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                itemSummary,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textColor,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                '${tx.itemCount} item • ${dateFmt.format(tx.createdAt)}',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.textLightColor,
                ),
              ),
            ],
          ),
        ),
        children: [
          // List Item Produk
          ...tx.items.map((item) => Padding(
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
                      'Rp ${fmt.format(item.subtotal)}',
                      style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.textLightColor,
                          fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              )),
          const Divider(height: 16, color: Color(0xFFE2E8F0)),

          // Subtotal
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Subtotal',
                  style: TextStyle(fontSize: 12, color: AppTheme.textLightColor)),
              Text('Rp ${fmt.format(tx.subtotal)}',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textColor)),
            ],
          ),

          // Diskon (jika ada)
          if (tx.billDiscount > 0) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Diskon',
                    style: TextStyle(fontSize: 12, color: AppTheme.dangerColor)),
                Text('- Rp ${fmt.format(tx.billDiscount)}',
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.dangerColor)),
              ],
            ),
          ],

          // PPN (jika ada)
          if (tx.taxAmount > 0) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('PPN ${tx.taxRate}%',
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textLightColor)),
                Text('Rp ${fmt.format(tx.taxAmount)}',
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textColor)),
              ],
            ),
          ],

          // Total
          if (tx.billDiscount > 0 || tx.taxAmount > 0) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textColor)),
                Text('Rp ${fmt.format(tx.total)}',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor)),
              ],
            ),
          ],

          // Tunai / Kembali
          if (tx.cashReceived > 0) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Tunai / Kembali',
                    style: TextStyle(
                        fontSize: 11, color: AppTheme.textLightColor)),
                Text(
                  'Rp ${fmt.format(tx.cashReceived)} / Rp ${fmt.format(tx.changeAmount)}',
                  style: const TextStyle(
                      fontSize: 11, color: AppTheme.textLightColor),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _expensesCard(BuildContext context) {
    final fmt = NumberFormat.decimalPattern('id');
    final dateFmt = DateFormat('dd/MM/yyyy');
    final items = summary.expenses.take(100).toList();
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
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
          title: Text(
            'Pengeluaran (${summary.expenses.length})',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.textColor,
            ),
          ),
          childrenPadding: const EdgeInsets.only(bottom: 8),
          children: [
            for (final e in items)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: Colors.grey.shade200)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            e.itemName,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.textColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${e.categoryName} • ${dateFmt.format(e.createdAt)}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.textLightColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '- Rp ${fmt.format(e.amount)}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.dangerColor,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}