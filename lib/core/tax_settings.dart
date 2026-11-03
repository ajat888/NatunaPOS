// lib/core/tax_settings.dart
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Pengaturan pajak global (PPN). Disimpan di SharedPreferences.
/// [rate] dipakai saat Payment Dialog dibuka, lalu di-snapshot ke transaksi.
class TaxSettings {
  TaxSettings._();
  static final TaxSettings instance = TaxSettings._();

  static const String _kEnabled = 'natunapos_tax_enabled';
  static const String _kRate = 'natunapos_tax_rate';
  static const double defaultRate = 11.0;

  final ValueNotifier<bool> enabled = ValueNotifier(false);
  final ValueNotifier<double> rate = ValueNotifier(defaultRate);

  bool get isEnabled => enabled.value;
  double get currentRate => rate.value;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      enabled.value = prefs.getBool(_kEnabled) ?? false;
      rate.value = prefs.getDouble(_kRate) ?? defaultRate;
    } catch (e) {
      debugPrint('TaxSettings load failed: $e');
    }
  }

  Future<void> setEnabled(bool value) async {
    enabled.value = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kEnabled, value);
    } catch (e) {
      debugPrint('TaxSettings setEnabled failed: $e');
    }
  }

  Future<void> setRate(double value) async {
    final clamped = value.clamp(0.0, 100.0).toDouble();
    rate.value = clamped;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_kRate, clamped);
    } catch (e) {
      debugPrint('TaxSettings setRate failed: $e');
    }
  }
}