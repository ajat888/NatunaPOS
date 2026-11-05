part of 'printer_service.dart';

extension _ReceiptGenerator on PrinterService {
  Future<List<int>> _generateReceiptBytes(
      Transaction tx, Generator generator) async {
    final settings = AppSettings.instance;
    final List<int> bytes = [];

    bytes.addAll(generator.reset());

    final logoPath = settings.logoPath.value;
    if (logoPath != null && File(logoPath).existsSync()) {
      try {
        final rawImage = img.decodeImage(File(logoPath).readAsBytesSync());
        if (rawImage != null) {
          final resizedImage = img.copyResize(rawImage, width: 180);
          bytes.addAll(generator.imageRaster(
            resizedImage,
            align: PosAlign.center,
          ));
        }
      } catch (e) {
        debugPrint('Render logo failed: $e');
      }
    }

    bytes.addAll(generator.text(
      settings.storeName.value.toUpperCase(),
      styles: PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2, width: PosTextSize.size2),
    ));

    if (settings.storeSubtitle.value.isNotEmpty) {
      bytes.addAll(generator.text(
        settings.storeSubtitle.value,
        styles: const PosStyles(align: PosAlign.center, bold: false),
      ));
    }

    if (settings.storeAddress.value.isNotEmpty) {
      bytes.addAll(generator.text(
        settings.storeAddress.value,
        styles: const PosStyles(align: PosAlign.center),
      ));
    }

    if (settings.storePhone.value.isNotEmpty) {
      bytes.addAll(generator.text(
        'Telp: ${settings.storePhone.value}',
        styles: const PosStyles(align: PosAlign.center),
      ));
    }

    bytes.addAll(generator.hr());

    final dateFmt = DateFormat('yyyyMMdd').format(tx.createdAt);
    final timeFmt = DateFormat('yyyy-MM-dd HH:mm:ss').format(tx.createdAt);
    final noNota = 'NTN-$dateFmt-${tx.id.toString().padLeft(4, '0')}';
    final table = tx.tableNumber ?? '-';

    bytes.addAll(generator.row([
      PosColumn(text: 'No. Nota', width: 4),
      PosColumn(text: ': $noNota', width: 8),
    ]));
    bytes.addAll(generator.row([
      PosColumn(text: 'Meja', width: 4),
      PosColumn(text: ': $table', width: 8),
    ]));
    bytes.addAll(generator.row([
      PosColumn(text: 'Waktu', width: 4),
      PosColumn(text: ': $timeFmt', width: 8),
    ]));

    bytes.addAll(generator.hr());

    for (final item in tx.items) {
      bytes.addAll(generator.text(item.productName, styles: const PosStyles(bold: true)));
      final sub = NumberFormat.decimalPattern('id').format(item.subtotal);
      final prc = NumberFormat.decimalPattern('id').format(item.price);
      bytes.addAll(generator.row([
        PosColumn(text: '${item.qty} x Rp $prc', width: 6),
        PosColumn(text: 'Rp $sub', width: 6, styles: const PosStyles(align: PosAlign.right)),
      ]));
    }

    bytes.addAll(generator.hr());

    final fmt = NumberFormat.decimalPattern('id');
    bytes.addAll(generator.row([
      PosColumn(text: 'Subtotal', width: 6, styles: const PosStyles(bold: true)),
      PosColumn(text: 'Rp ${fmt.format(tx.subtotal)}', width: 6, styles: const PosStyles(align: PosAlign.right)),
    ]));

    if (tx.billDiscount > 0) {
      bytes.addAll(generator.row([
        PosColumn(text: 'Diskon', width: 6, styles: const PosStyles(bold: true)),
        PosColumn(text: '-Rp ${fmt.format(tx.billDiscount)}', width: 6, styles: const PosStyles(align: PosAlign.right)),
      ]));
    }

    if (tx.taxAmount > 0) {
      bytes.addAll(generator.row([
        PosColumn(text: 'PPN ${tx.taxRate}%', width: 6, styles: const PosStyles(bold: true)),
        PosColumn(text: 'Rp ${fmt.format(tx.taxAmount)}', width: 6, styles: const PosStyles(align: PosAlign.right)),
      ]));
    }

    bytes.addAll(generator.row([
      PosColumn(text: 'TOTAL', width: 6, styles: const PosStyles(bold: true)),
      PosColumn(text: 'Rp ${fmt.format(tx.total)}', width: 6, styles: const PosStyles(align: PosAlign.right, bold: true)),
    ]));

    bytes.addAll(generator.row([
      PosColumn(text: 'BAYAR', width: 6, styles: const PosStyles(bold: true)),
      PosColumn(text: 'Rp ${fmt.format(tx.cashReceived)}', width: 6, styles: const PosStyles(align: PosAlign.right)),
    ]));

    bytes.addAll(generator.row([
      PosColumn(text: 'KEMBALI', width: 6, styles: const PosStyles(bold: true)),
      PosColumn(text: 'Rp ${fmt.format(tx.changeAmount)}', width: 6, styles: const PosStyles(align: PosAlign.right)),
    ]));

    bytes.addAll(generator.hr());

    if (settings.receiptFooter.value.isNotEmpty) {
      bytes.addAll(generator.text(
        settings.receiptFooter.value,
        styles: const PosStyles(align: PosAlign.center),
      ));
      bytes.addAll(generator.feed(1));
    }

    bytes.addAll(generator.text(
      'Terima Kasih',
      styles: const PosStyles(align: PosAlign.center, bold: true),
    ));

    bytes.addAll(generator.feed(2));
    bytes.addAll(generator.cut());

    return bytes;
  }
}