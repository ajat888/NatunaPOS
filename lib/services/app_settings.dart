import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  AppSettings._();
  static final AppSettings instance = AppSettings._();

  static const String _kStoreName = 'natunapos_store_name';
  static const String _kStoreSubtitle = 'natunapos_store_subtitle';
  static const String _kStoreAddress = 'natunapos_store_address';
  static const String _kStorePhone = 'natunapos_store_phone';
  static const String _kReceiptFooter = 'natunapos_receipt_footer';
  static const String _kCashierName = 'natunapos_cashier_name';
  static const String _kLogoPath = 'natunapos_logo_path';
  static const String _kPrinterMac = 'natunapos_printer_mac';
  static const String _kPrinterName = 'natunapos_printer_name';

  final ValueNotifier<String> storeName = ValueNotifier('');
  final ValueNotifier<String> storeSubtitle = ValueNotifier('');
  final ValueNotifier<String> storeAddress = ValueNotifier('');
  final ValueNotifier<String> storePhone = ValueNotifier('');
  final ValueNotifier<String> receiptFooter = ValueNotifier('');
  final ValueNotifier<String> cashierName = ValueNotifier('');
  final ValueNotifier<String?> logoPath = ValueNotifier(null);
  final ValueNotifier<String?> printerMac = ValueNotifier(null);
  final ValueNotifier<String?> printerName = ValueNotifier(null);

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      storeName.value = prefs.getString(_kStoreName) ?? '';
      storeSubtitle.value = prefs.getString(_kStoreSubtitle) ?? '';
      storeAddress.value = prefs.getString(_kStoreAddress) ?? '';
      storePhone.value = prefs.getString(_kStorePhone) ?? '';
      receiptFooter.value = prefs.getString(_kReceiptFooter) ?? '';
      cashierName.value = prefs.getString(_kCashierName) ?? '';
      logoPath.value = prefs.getString(_kLogoPath);
      printerMac.value = prefs.getString(_kPrinterMac);
      printerName.value = prefs.getString(_kPrinterName);
    } catch (e) {
      debugPrint('AppSettings load failed: $e');
    }
  }

  Future<void> saveStoreInfo({
    required String name,
    required String subtitle,
    required String address,
    required String phone,
    required String footer,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kStoreName, name.trim());
    await prefs.setString(_kStoreSubtitle, subtitle.trim());
    await prefs.setString(_kStoreAddress, address.trim());
    await prefs.setString(_kStorePhone, phone.trim());
    await prefs.setString(_kReceiptFooter, footer.trim());

    storeName.value = name.trim();
    storeSubtitle.value = subtitle.trim();
    storeAddress.value = address.trim();
    storePhone.value = phone.trim();
    receiptFooter.value = footer.trim();
  }

  Future<void> saveCashierName(String name) async {
    final trimmed = name.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kCashierName, trimmed);
    cashierName.value = trimmed;
  }

  Future<void> saveLogoPath(String? path) async {
    final prefs = await SharedPreferences.getInstance();
    if (path == null) {
      await prefs.remove(_kLogoPath);
    } else {
      await prefs.setString(_kLogoPath, path);
    }
    logoPath.value = path;
  }

  Future<void> savePrinter(String? mac, String? name) async {
    final prefs = await SharedPreferences.getInstance();
    if (mac == null) {
      await prefs.remove(_kPrinterMac);
      await prefs.remove(_kPrinterName);
    } else {
      await prefs.setString(_kPrinterMac, mac);
      await prefs.setString(_kPrinterName, name ?? '');
    }
    printerMac.value = mac;
    printerName.value = name;
  }
}