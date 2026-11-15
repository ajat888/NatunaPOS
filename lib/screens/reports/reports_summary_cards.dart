part of '../reports_screen.dart';

class _ReportsSummaryCards extends StatelessWidget {
  final ReportSummary summary;
  const _ReportsSummaryCards({required this.summary});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.decimalPattern('id');
    final avgTx = summary.totalTransactions > 0 
        ? (summary.totalSales / summary.totalTransactions).round() 
        : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSmartInsight(context),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _summaryCard(
                'Total Penjualan',
                'Rp ${fmt.format(summary.totalSales)}',
                Icons.account_balance_wallet_outlined,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _summaryCard(
                'Transaksi',
                '${summary.totalTransactions}',
                Icons.receipt_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _summaryCard(
                'Pengeluaran',
                '- Rp ${fmt.format(summary.totalExpenses)}',
                Icons.money_off,
                danger: summary.totalExpenses > 0,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _summaryCard(
                'Laba Bersih',
                'Rp ${fmt.format(summary.netProfit)}',
                Icons.trending_up,
                danger: summary.netProfit < 0,
                positive: summary.netProfit >= 0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _detailsCard(context, fmt, avgTx),
      ],
    );
  }

  Widget _buildSmartInsight(BuildContext context) {
    if (summary.totalTransactions == 0) return const SizedBox.shrink();

    if (summary.netProfit < 0) {
      return _insightBanner(
        context,
        icon: Icons.warning_amber_rounded,
        color: AppTheme.dangerColor,
        title: 'Perhatian: Bisnis Rugi',
        message: 'Pengeluaran Anda melebihi Laba Kotor. Evaluasi pengeluaran atau tingkatkan penjualan.',
      );
    } else if (summary.totalExpenses > (summary.totalSales * 0.3)) {
      return _insightBanner(
        context,
        icon: Icons.info_outline,
        color: Colors.orange.shade800,
        title: 'Peringatan Pengeluaran',
        message: 'Pengeluaran Anda mencapai lebih dari 30% dari Omzet. Cek kembali pengeluaran terbesar Anda.',
      );
    } else {
      return _insightBanner(
        context,
        icon: Icons.check_circle_outline,
        color: Colors.green.shade700,
        title: 'Bisnis Sehat',
        message: 'Laba bersih positif dan pengeluaran terkendali. Pertahankan!',
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
                'ALUR LABA RUGI',
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
          _row('Omzet (Total Penjualan)', 'Rp ${fmt.format(summary.totalSales)}', bold: true),
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
                    const Text('(-) HPP (Modal Bahan)', style: TextStyle(fontSize: 12, color: AppTheme.dangerColor)),
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: () => _showSpecificInfo(context, 'HPP (Harga Pokok Penjualan)', 'Biaya modal bahan baku yang melekat pada menu yang terjual hari ini. Contoh: harga daging, beras, dan sayur di piring pelanggan.'),
                      child: const Icon(Icons.info_outline, size: 14, color: AppTheme.textLightColor),
                    ),
                  ],
                ),
              ),
              Text('Rp ${fmt.format(summary.totalHpp)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.dangerColor)),
            ],
          ),
          const Divider(height: 16, color: Color(0xFFE2E8F0)),
          _row('Laba Kotor', 'Rp ${fmt.format(summary.grossProfit)}', bold: true),
          const SizedBox(height: 6),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Text('(-) Pengeluaran Operasional', style: TextStyle(fontSize: 12, color: AppTheme.dangerColor)),
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: () => _showSpecificInfo(context, 'Pengeluaran Operasional', 'Biaya di luar menu yang dikeluarkan hari ini, seperti beli stok bulanan (beras/gas), gaji karyawan, listrik, atau peralatan.'),
                      child: const Icon(Icons.info_outline, size: 14, color: AppTheme.textLightColor),
                    ),
                  ],
                ),
              ),
              Text('Rp ${fmt.format(summary.totalExpenses)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.dangerColor)),
            ],
          ),
          const Divider(height: 16, color: Color(0xFFE2E8F0)),
          _row('Laba Bersih', 'Rp ${fmt.format(summary.netProfit)}', 
              bold: true, 
              danger: summary.netProfit < 0, 
              positive: summary.netProfit >= 0),

          const SizedBox(height: 16),
          const Divider(height: 20, color: Color(0xFFE2E8F0)),
          
          // Info Tambahan
          _row('Total Item Terjual', '${summary.totalItems} item'),
          const SizedBox(height: 6),
          _row('Rata-rata Belanja / Transaksi', 'Rp ${fmt.format(avgTx)}'),
          const SizedBox(height: 6),

          if (summary.voidTransactionCount > 0) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Transaksi Dibatalkan', style: TextStyle(fontSize: 12, color: AppTheme.dangerColor)),
                    Text('(Tidak masuk omzet)', style: TextStyle(fontSize: 10, color: AppTheme.textLightColor)),
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
                    Text('(Tidak masuk omzet)', style: TextStyle(fontSize: 10, color: AppTheme.textLightColor)),
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
            _row('Pembatalan (Void)', 'Tidak ada', danger: false),
            const SizedBox(height: 6),
          ],

          const Divider(height: 20, color: Color(0xFFE2E8F0)),
          
          // PEMISAHAN TUNAI & NON-TUNAI
          _row(
            'Penerimaan Tunai (Cash)',
            'Rp ${fmt.format(summary.cashExpected)}',
            bold: true,
          ),
          const SizedBox(height: 6),
          _row(
            'Penerimaan Non-Tunai (QRIS/Transfer)',
            'Rp 0', // Placeholder
            bold: false,
          ),
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

  void _showSpecificInfo(BuildContext context, String title, String message) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        title: Text(title),
        content: Text(message, style: const TextStyle(fontSize: 13, color: AppTheme.textColor)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('MENGERTI')),
        ],
      ),
    );
  }

  void _showDetailInfo(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        title: const Text('Informasi Alur Laba'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Laba Kotor', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textColor)),
            SizedBox(height: 4),
            Text('Omzet Penjualan dikurangi HPP (Harga Modal Bahan). Ini adalah keuntungan kotor sebelum dipotong biaya operasional.', style: TextStyle(fontSize: 12, color: AppTheme.textLightColor)),
            SizedBox(height: 12),
            Text('Laba Bersih', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textColor)),
            SizedBox(height: 4),
            Text('Laba Kotor dikurangi Pengeluaran Operasional (listrik, gaji, bahan tambahan, dll). Ini adalah uang bersih yang Anda kantongi.', style: TextStyle(fontSize: 12, color: AppTheme.textLightColor)),
            SizedBox(height: 12),
            Text('Penerimaan Tunai (Cash)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textColor)),
            SizedBox(height: 4),
            Text('Uang fisik (tunai) yang seharusnya ada di laci kasir dari penjualan. Belum dikurangi pengeluaran.', style: TextStyle(fontSize: 12, color: AppTheme.textLightColor)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('MENGERTI')),
        ],
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