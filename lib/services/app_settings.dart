import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  AppSettings._();
  static final AppSettings instance = AppSettings._();

  static const String _kStoreName = 'natunapos_store_name';
  static const String _kStoreAddress = 'natunapos_store_address';
  static const String _kStorePhone = 'natunapos_store_phone';
  static const String _kReceiptFooter = 'natunapos_receipt_footer';
  static const String _kCashierName = 'natunapos_cashier_name';

  final ValueNotifier<String> storeName = ValueNotifier('');
  final ValueNotifier<String> storeAddress = ValueNotifier('');
  final ValueNotifier<String> storePhone = ValueNotifier('');
  final ValueNotifier<String> receiptFooter = ValueNotifier('');
  final ValueNotifier<String> cashierName = ValueNotifier('');

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      storeName.value = prefs.getString(_kStoreName) ?? '';
      storeAddress.value = prefs.getString(_kStoreAddress) ?? '';
      storePhone.value = prefs.getString(_kStorePhone) ?? '';
      receiptFooter.value = prefs.getString(_kReceiptFooter) ?? '';
      cashierName.value = prefs.getString(_kCashierName) ?? '';
    } catch (e) {
      debugPrint('AppSettings load failed: $e');
    }
  }

  Future<void> saveStoreInfo({
    required String name,
    required String address,
    required String phone,
    required String footer,
  }) async {
    final trimmedName = name.trim();
    final trimmedAddress = address.trim();
    final trimmedPhone = phone.trim();
    final trimmedFooter = footer.trim();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kStoreName, trimmedName);
    await prefs.setString(_kStoreAddress, trimmedAddress);
    await prefs.setString(_kStorePhone, trimmedPhone);
    await prefs.setString(_kReceiptFooter, trimmedFooter);

    storeName.value = trimmedName;
    storeAddress.value = trimmedAddress;
    storePhone.value = trimmedPhone;
    receiptFooter.value = trimmedFooter;
  }

  Future<void> saveCashierName(String name) async {
    final trimmed = name.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kCashierName, trimmed);
    cashierName.value = trimmed;
  }
}