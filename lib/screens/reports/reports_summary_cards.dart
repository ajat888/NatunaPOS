part of '../reports_screen.dart';

class _ReportsSummaryCards extends StatelessWidget {
  final ReportSummary summary;
  const _ReportsSummaryCards({required this.summary});

@override
Widget build(BuildContext context) {
  final fmt = NumberFormat.decimalPattern('id');

  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _buildSmartInsight(context),
      const SizedBox(height: 12),
      _summaryCard(
        'Pemasukan',
        'Rp ${fmt.format(summary.totalSales)}',
        Icons.account_balance_wallet_outlined,
        subtitle: 'Dari ${summary.totalTransactions} transaksi',
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: _summaryCard(
              'Uang Tunai di Laci',
              'Rp ${fmt.format(summary.cashExpected)}',
              Icons.payments_outlined,
              subtitle: 'Dari penjualan tunai; belum dikurangi belanja',
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _summaryCard(
              'Untung Bersih',
              'Rp ${fmt.format(summary.netProfit)}',
              Icons.trending_up,
              danger: summary.netProfit < 0,
              positive: summary.netProfit >= 0,
              subtitle: summary.netProfit >= 0
                  ? 'Setelah modal bahan + pengeluaran lain'
                  : 'Rugi: biaya lebih besar dari pemasukan',
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
      Container(
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            title: const Text(
              'Lihat Rincian Perhitungan',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            iconColor: AppTheme.primaryColor,
            collapsedIconColor: AppTheme.textLightColor,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: _detailsCard(context, fmt, summary.totalTransactions > 0
                    ? (summary.totalSales / summary.totalTransactions).round()
                    : 0),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 10),
      const Row(
        children: [
          Icon(Icons.auto_awesome, size: 12, color: AppTheme.textLightColor),
          SizedBox(width: 4),
          Expanded(
            child: Text(
              'Butuh saran? Ketuk ikon ✨ di kanan atas untuk Analisis AI.',
              style: TextStyle(fontSize: 10, color: AppTheme.textLightColor),
            ),
          ),
        ],
      ),
    ],
  );
}

Widget _buildSmartInsight(BuildContext context) {
  final fmt = NumberFormat.decimalPattern('id');
  if (summary.totalTransactions == 0) {
    final belanja = summary.totalExpenses + summary.totalStockPurchases;
    if (belanja <= 0) return const SizedBox.shrink();
    return _insightBanner(
      context,
      icon: Icons.info_outline,
      color: Colors.orange.shade800,
      title: 'Belum ada penjualan',
      message:
          'Belum ada pemasukan pada periode ini, tetapi sudah ada belanja Rp ${fmt.format(belanja)}. Pastikan transaksi penjualan memang belum terjadi, bukan belum tercatat.',
    );
  }

  String topExpenseText = '';
  if (summary.expenses.isNotEmpty) {
    final sortedExp = List<Expense>.from(summary.expenses)
      ..sort((a, b) => b.amount.compareTo(a.amount));
    final top = sortedExp.first;
    topExpenseText =
        ' Pengeluaran lain terbesar: ${top.itemName} (Rp ${fmt.format(top.amount)}).';
  }

  if (summary.netProfit < 0) {
    return _insightBanner(
      context,
      icon: Icons.warning_amber_rounded,
      color: AppTheme.dangerColor,
      title: 'Periode ini rugi',
      message:
          'Total biaya lebih besar dari pemasukan, selisihnya Rp ${fmt.format(-summary.netProfit)}.$topExpenseText Kurangi pengeluaran lain atau naikkan harga jual.',
    );
  } else if (summary.totalExpenses * 3 > summary.totalSales) {
    return _insightBanner(
      context,
      icon: Icons.info_outline,
      color: Colors.orange.shade800,
      title: 'Pengeluaran lain tinggi',
      message:
          'Pengeluaran lain Rp ${fmt.format(summary.totalExpenses)} lebih dari sepertiga pemasukan.$topExpenseText Cek lagi apakah belanja ini perlu.',
    );
  } else {
    return _insightBanner(
      context,
      icon: Icons.check_circle_outline,
      color: Colors.green.shade700,
      title: 'Periode ini untung',
      message:
          'Untung bersih Rp ${fmt.format(summary.netProfit)}. Pantau terus pengeluaran lain.',
    );
  }
}

  Widget _insightBanner(BuildContext context, {
    required IconData icon, 
    required Color color, 
    required String title, 
    required String message
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textColor,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryCard(
  String title,
  String value,
  IconData icon, {
  bool danger = false,
  bool positive = false,
  String? subtitle,
}) {
  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppTheme.surfaceColor,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: const Color(0xFFE2E8F0)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(
            icon,
            size: 16,
            color: danger ? AppTheme.dangerColor : AppTheme.textLightColor,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 11,
                color: danger ? AppTheme.dangerColor : AppTheme.textLightColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ]),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: danger
                ? AppTheme.dangerColor
                : (positive ? Colors.green.shade700 : AppTheme.textColor),
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 10, color: AppTheme.textLightColor),
          ),
        ]
      ],
    ),
  );
}

  Widget _detailsCard(BuildContext context, NumberFormat fmt, int avgTx) {
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
              const Text(
                'CARA MENGHITUNG UNTUNG',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: AppTheme.textLightColor,
                ),
              ),
              const SizedBox(width: 4),
              InkWell(
                onTap: () => _showDetailInfo(context),
                borderRadius: BorderRadius.circular(16),
                child: const Padding(
                  padding: EdgeInsets.all(2.0),
                  child: Icon(
                    Icons.help_outline,
                    size: 16,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Alur Perhitungan Laba Bersih
          _row('Pemasukan',  'Rp ${fmt.format(summary.totalSales)}', bold: true),
          const SizedBox(height: 6),
          
          // PROGRESS BAR VISUAL
          if (summary.totalSales > 0) ...[
            _buildProgressBar(),
            const SizedBox(height: 12),
          ],

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Text('(-) Modal bahan',  style: TextStyle(fontSize: 12, color: AppTheme.dangerColor)),
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: () => _showSpecificInfo(context, 'Modal bahan', 'Modal bahan dari setiap menu yang terjual, misalnya harga daging, beras, dan sayur di piring pelanggan. Angkanya diambil dari modal bahan per menu yang Anda isi di daftar menu.'),
                      child: const Icon(Icons.info_outline, size: 14, color: AppTheme.textLightColor),
                    ),
                  ],
                ),
              ),
              Text('Rp ${fmt.format(summary.totalHpp)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.dangerColor)),
            ],
          ),
          const Divider(height: 16, color: Color(0xFFE2E8F0)),
          _row('Untung kotor', 'Rp ${fmt.format(summary.grossProfit)}', bold: true),
          const SizedBox(height: 6),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Text('(-) Pengeluaran lain', style: TextStyle(fontSize: 12, color: AppTheme.dangerColor)),
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: () => _showSpecificInfo(context, 'Pengeluaran lain', 'Biaya di luar modal bahan menu, seperti listrik, gaji, dan peralatan.'),
                      child: const Icon(Icons.info_outline, size: 14, color: AppTheme.textLightColor),
                    ),
                  ],
                ),
              ),
              Text('Rp ${fmt.format(summary.totalExpenses)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.dangerColor)),
            ],
          ),
          const Divider(height: 16, color: Color(0xFFE2E8F0)),
          _row('Untung bersih', 'Rp ${fmt.format(summary.netProfit)}',
               bold: true, 
              danger: summary.netProfit < 0, 
              positive: summary.netProfit >= 0),

          const SizedBox(height: 6),
          _row('Belanja stok bahan (bukan biaya periode ini)', 'Rp ${fmt.format(summary.totalStockPurchases)}'),
          
          const SizedBox(height: 16),
          const Divider(height: 20, color: Color(0xFFE2E8F0)),
          
          // Info Tambahan
          _row('Jumlah item terjual', '${summary.totalItems} item'),
          const SizedBox(height: 6),
          _row('Rata-rata pemasukan per transaksi', 'Rp ${fmt.format(avgTx)}'),
          const SizedBox(height: 6),

          if (summary.voidTransactionCount > 0) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Transaksi Dibatalkan', style: TextStyle(fontSize: 12, color: AppTheme.dangerColor)),
                    Text('(Tidak masuk pemasukan)', style: TextStyle(fontSize: 10, color: AppTheme.textLightColor)),
                  ],
                ),
                Text(
                  '${summary.voidTransactionCount} • Rp ${fmt.format(summary.totalVoidAmount)}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.dangerColor),
                ),
              ],
            ),
            const SizedBox(height: 6),
          ],
          
          if (summary.voidOpenOrderCount > 0) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Pesanan Dibatalkan', style: TextStyle(fontSize: 12, color: AppTheme.dangerColor)),
                    Text('(Tidak masuk pemasukan)', style: TextStyle(fontSize: 10, color: AppTheme.textLightColor)),
                  ],
                ),
                Text(
                  '${summary.voidOpenOrderCount} • Rp ${fmt.format(summary.totalVoidOpenOrderAmount)}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.dangerColor),
                ),
              ],
            ),
            const SizedBox(height: 6),
          ],

          if (summary.voidTransactionCount == 0 && summary.voidOpenOrderCount == 0) ...[
            _row('Pembatalan', 'Tidak ada', danger: false),
            const SizedBox(height: 6),
          ],

          const Divider(height: 20, color: Color(0xFFE2E8F0)),
          
          _row(
            'Pembayaran QRIS (masuk rekening, bukan laci)',
            'Rp ${fmt.format(summary.qrisTotal)}',
            bold: false,
          ),
          if (summary.unknownPaymentTotal > 0) ...[
            const SizedBox(height: 6),
            _row('Tidak diketahui', 'Rp ${fmt.format(summary.unknownPaymentTotal)}', bold: false),
          ],
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    final hpp = summary.totalHpp.clamp(0, summary.totalSales);
    final exp = summary.totalExpenses.clamp(0, summary.totalSales - hpp);
    final profit = summary.netProfit > 0 ? summary.netProfit.clamp(0, summary.totalSales - hpp - exp) : 0;

    return Container(
      height: 10,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(5),
        color: const Color(0xFFE2E8F0),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: Row(
          children: [
            if (hpp > 0) Expanded(flex: hpp, child: Container(color: AppTheme.dangerColor)),
            if (exp > 0) Expanded(flex: exp, child: Container(color: Colors.orange.shade800)),
            if (profit > 0) Expanded(flex: profit, child: Container(color: Colors.green.shade700)),
          ],
        ),
      ),
    );
  }

  Widget _row(
    String label,
    String value, {
    bool danger = false,
    bool bold = false,
    bool positive = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
              color: danger ? AppTheme.dangerColor : AppTheme.textLightColor,
            ),
          ),
        ),
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
    );
  }
}