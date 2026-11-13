import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auto_sync_scheduler.dart';

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
  static const String _kLogoUrl = 'natunapos_logo_url';
  static const String _kPrinterMac = 'natunapos_printer_mac';
  static const String _kPrinterName = 'natunapos_printer_name';
  static const String _kSettingsDirty = 'natunapos_settings_dirty';
  static const String _kLogoDirty = 'natunapos_logo_dirty';
  static const String _kSettingsUpdatedAtMs =
      'natunapos_settings_updated_at_ms';
  static const String _kTableCount = 'natunapos_table_count';
  static const String _kPosCategoryOrder = 'natunapos_pos_category_order';

  final ValueNotifier<String> storeName = ValueNotifier('');
  final ValueNotifier<String> storeSubtitle = ValueNotifier('');
  final ValueNotifier<String> storeAddress = ValueNotifier('');
  final ValueNotifier<String> storePhone = ValueNotifier('');
  final ValueNotifier<String> receiptFooter = ValueNotifier('');
  final ValueNotifier<String> cashierName = ValueNotifier('');
  final ValueNotifier<String?> logoPath = ValueNotifier(null);
  final ValueNotifier<String?> printerMac = ValueNotifier(null);
  final ValueNotifier<String?> printerName = ValueNotifier(null);
  final ValueNotifier<int> tableCount = ValueNotifier(20);
  final ValueNotifier<List<int>> posCategoryOrder = ValueNotifier([]);

  String? _logoUrl;
  bool _isDirty = false;
  bool _isLogoDirty = false;
  int _updatedAtMs = 0;

  String? get logoUrl => _logoUrl;
  bool get isDirty => _isDirty;
  bool get isLogoDirty => _isLogoDirty;
  int get updatedAtMs => _updatedAtMs;

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
      _logoUrl = prefs.getString(_kLogoUrl);
      printerMac.value = prefs.getString(_kPrinterMac);
      printerName.value = prefs.getString(_kPrinterName);
      _isDirty = prefs.getBool(_kSettingsDirty) ?? false;
      _isLogoDirty = prefs.getBool(_kLogoDirty) ?? false;
      _updatedAtMs = prefs.getInt(_kSettingsUpdatedAtMs) ?? 0;
      
      final loaded = prefs.getInt(_kTableCount) ?? 20;
      tableCount.value = loaded.clamp(1, 200);

      final orderList = prefs.getStringList(_kPosCategoryOrder);
      if (orderList != null) {
        posCategoryOrder.value = orderList
            .map((e) => int.tryParse(e) ?? -2)
            .where((e) => e != -2)
            .toList();
      }
    } catch (e) {
      debugPrint('AppSettings load failed: $e');
    }
  }

  Future<void> markDirty({bool triggerSync = true}) async {
    _isDirty = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kSettingsDirty, true);
    } catch (e) {
      debugPrint('AppSettings markDirty failed: $e');
    }
    if (triggerSync) AutoSyncScheduler.instance.scheduleSync();
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
    await markDirty();
  }

  Future<void> saveTableCount(int count) async {
    final clamped = count.clamp(1, 200).toInt();
    tableCount.value = clamped;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kTableCount, clamped);
      await markDirty();
    } catch (e) {
      debugPrint('AppSettings saveTableCount failed: $e');
    }
  }

  Future<void> savePosCategoryOrder(List<int> order) async {
    posCategoryOrder.value = order;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
          _kPosCategoryOrder, order.map((e) => e.toString()).toList());
    } catch (e) {
      debugPrint('AppSettings savePosCategoryOrder failed: $e');
    }
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
    _isLogoDirty = true;
    await prefs.setBool(_kLogoDirty, true);
    await markDirty();
  }

  Future<void> saveLogoUrl(String? url) async {
    _logoUrl = url;
    final prefs = await SharedPreferences.getInstance();
    if (url == null) {
      await prefs.remove(_kLogoUrl);
    } else {
      await prefs.setString(_kLogoUrl, url);
    }
  }

  Future<void> clearLogoDirty() async {
    _isLogoDirty = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kLogoDirty, false);
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

  Map<String, dynamic> toServerJson({String? logoUrl}) {
    return {
      'store_name': storeName.value,
      'store_subtitle': storeSubtitle.value,
      'store_address': storeAddress.value,
      'store_phone': storePhone.value,
      'receipt_footer': receiptFooter.value,
      'logo_url': logoUrl,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
  }

  Future<void> markSynced(int serverUpdatedAtMs) async {
    _isDirty = false;
    _isLogoDirty = false;
    _updatedAtMs = serverUpdatedAtMs;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kSettingsDirty, false);
    await prefs.setBool(_kLogoDirty, false);
    await prefs.setInt(_kSettingsUpdatedAtMs, serverUpdatedAtMs);
  }

  Future<void> applyFromServer({
    required String storeName,
    required String storeSubtitle,
    required String storeAddress,
    required String storePhone,
    required String receiptFooter,
    required String? logoPath,
    required String? logoUrl,
    required int serverUpdatedAtMs,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    this.storeName.value = storeName;
    this.storeSubtitle.value = storeSubtitle;
    this.storeAddress.value = storeAddress;
    this.storePhone.value = storePhone;
    this.receiptFooter.value = receiptFooter;
    this.logoPath.value = logoPath;
    _logoUrl = logoUrl;

    await prefs.setString(_kStoreName, storeName);
    await prefs.setString(_kStoreSubtitle, storeSubtitle);
    await prefs.setString(_kStoreAddress, storeAddress);
    await prefs.setString(_kStorePhone, storePhone);
    await prefs.setString(_kReceiptFooter, receiptFooter);
    if (logoPath != null) {
      await prefs.setString(_kLogoPath, logoPath);
    } else {
      await prefs.remove(_kLogoPath);
    }
    if (logoUrl != null) {
      await prefs.setString(_kLogoUrl, logoUrl);
    } else {
      await prefs.remove(_kLogoUrl);
    }

    _isDirty = false;
    _isLogoDirty = false;
    _updatedAtMs = serverUpdatedAtMs;
    await prefs.setBool(_kSettingsDirty, false);
    await prefs.setBool(_kLogoDirty, false);
    await prefs.setInt(_kSettingsUpdatedAtMs, serverUpdatedAtMs);
  }
}