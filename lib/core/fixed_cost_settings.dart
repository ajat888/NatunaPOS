import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/app_settings.dart';

class FixedCostSettings {
  FixedCostSettings._();
  static final FixedCostSettings instance = FixedCostSettings._();

  static const String _kMonthly = 'natunapos_fixed_cost_monthly';

  final ValueNotifier<int> monthly = ValueNotifier(0);

  int get currentMonthly => monthly.value;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      monthly.value = prefs.getInt(_kMonthly) ?? 0;
    } catch (e) {
      debugPrint('FixedCostSettings load failed: $e');
    }
  }

  Future<void> setMonthly(int value) async {
    final clamped = value < 0 ? 0 : value;
    monthly.value = clamped;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kMonthly, clamped);
      await AppSettings.instance.markDirty();
    } catch (e) {
      debugPrint('FixedCostSettings setMonthly failed: $e');
    }
  }

  // Dipakai saat nilai diterima dari server; tidak menandai pengaturan berubah.
  Future<void> applyFromServer(int value) async {
    final clamped = value < 0 ? 0 : value;
    monthly.value = clamped;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kMonthly, clamped);
    } catch (e) {
      debugPrint('FixedCostSettings applyFromServer failed: $e');
    }
  }
}