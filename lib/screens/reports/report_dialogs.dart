part of '../reports_screen.dart';

void _showSpecificInfo(BuildContext context, String title, String message) {
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      title: Text(title),
      content: Text(message,
          style: const TextStyle(fontSize: 13, color: AppTheme.textColor)),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('MENGERTI')),
      ],
    ),
  );
}

void _showDetailInfo(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      title: const Text('Cara menghitung untung'),
      content: const SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('1. Pemasukan',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: AppTheme.textColor)),
            SizedBox(height: 4),
            Text(
                'Semua uang dari penjualan pada periode ini. Transaksi yang dibatalkan tidak dihitung.',
                style: TextStyle(fontSize: 12, color: AppTheme.textLightColor)),
            SizedBox(height: 12),
            Text('2. Modal bahan',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: AppTheme.textColor)),
            SizedBox(height: 4),
            Text(
                'Nilai bahan pada menu yang terjual. Bukan semua belanja bahan, hanya bahan yang sudah jadi penjualan.',
                style: TextStyle(fontSize: 12, color: AppTheme.textLightColor)),
            SizedBox(height: 12),
            Text('3. Untung kotor',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: AppTheme.textColor)),
            SizedBox(height: 4),
            Text('Pemasukan dikurangi modal bahan.',
                style: TextStyle(fontSize: 12, color: AppTheme.textLightColor)),
            SizedBox(height: 12),
            Text('4. Pengeluaran lain',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: AppTheme.textColor)),
            SizedBox(height: 4),
            Text(
                'Biaya di luar bahan menu, seperti listrik, gaji, sewa, dan peralatan.',
                style: TextStyle(fontSize: 12, color: AppTheme.textLightColor)),
            SizedBox(height: 12),
            Text('5. Untung bersih',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: AppTheme.textColor)),
            SizedBox(height: 4),
            Text(
                'Untung kotor dikurangi pengeluaran lain. Ini sisa untung setelah semua biaya periode ini.',
                style: TextStyle(fontSize: 12, color: AppTheme.textLightColor)),
            SizedBox(height: 12),
            Text('Uang tunai di laci',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: AppTheme.textColor)),
            SizedBox(height: 4),
            Text(
                'Uang fisik dari penjualan tunai yang seharusnya ada di laci kasir. Ini belum dikurangi belanja, jadi bukan untung.',
                style: TextStyle(fontSize: 12, color: AppTheme.textLightColor)),
            SizedBox(height: 12),
            Text('Belanja isi stok',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: AppTheme.textColor)),
            SizedBox(height: 4),
            Text(
                'Uang untuk membeli bahan persediaan, misalnya beras, minyak, atau gas. Uangnya sudah keluar, tetapi belum dihitung biaya karena bahannya belum terjual. Contoh: beli beras Rp 100.000, baru Rp 50.000 yang terpakai bulan ini — yang dihitung biaya hanya Rp 50.000.',
                style: TextStyle(fontSize: 12, color: AppTheme.textLightColor)),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('MENGERTI')),
      ],
    ),
  );
}
