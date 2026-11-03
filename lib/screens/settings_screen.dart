// lib/screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/theme.dart';
import '../core/tax_settings.dart';
import '../widgets/common/main_menu_scope.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _rateController = TextEditingController();
  final _rateFocus = FocusNode();
  bool _savingRate = false;

  @override
  void initState() {
    super.initState();
    TaxSettings.instance.enabled
        .addListener(_onTaxChanged);
    _syncRateText();
  }

  @override
  void dispose() {
    TaxSettings.instance.enabled.removeListener(_onTaxChanged);
    _rateController.dispose();
    _rateFocus.dispose();
    super.dispose();
  }

  void _onTaxChanged() {
    if (mounted) setState(() {});
  }

  void _syncRateText() {
    final r = TaxSettings.instance.currentRate;
    _rateController.text = r == r.roundToDouble()
        ? r.toInt().toString()
        : r.toString();
  }

  Future<void> _toggleTax(bool val) async {
    await TaxSettings.instance.setEnabled(val);
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _saveRate() async {
    final text = _rateController.text.trim().replaceAll(',', '.');
    final parsed = double.tryParse(text);
    if (parsed == null || parsed < 0 || parsed > 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Persentase harus 0 - 100'),
          backgroundColor: AppTheme.dangerColor,
        ),
      );
      return;
    }
    setState(() => _savingRate = true);
    await TaxSettings.instance.setRate(parsed);
    if (!mounted) return;
    setState(() => _savingRate = false);
    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Persentase PPN disimpan: ${parsed == parsed.roundToDouble() ? parsed.toInt() : parsed}%'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final enabled = TaxSettings.instance.isEnabled;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          tooltip: 'Menu',
          onPressed: () => MainMenuScope.of(context)?.openMenu(),
        ),
        title: const Text('Pengaturan'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionHeader('Pajak & Diskon'),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                SwitchListTile.adaptive(
                  title: const Text('Aktifkan PPN'),
                  subtitle: const Text(
                    'PPN akan ditambahkan ke total setiap transaksi',
                    style: TextStyle(fontSize: 12),
                  ),
                  value: enabled,
                  activeColor: AppTheme.primaryColor,
                  onChanged: _toggleTax,
                ),
                if (enabled) ...[
                  const Divider(height: 1, color: Color(0xFFE2E8F0)),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Persentase PPN',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _rateController,
                                focusNode: _rateFocus,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                      RegExp(r'[0-9.,]')),
                                ],
                                decoration: const InputDecoration(
                                  suffixText: '%',
                                  hintText: '11',
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton(
                              onPressed: _savingRate ? null : _saveRate,
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 18),
                              ),
                              child: _savingRate
                                  ? const SizedBox(
                                      height: 16,
                                      width: 16,
                                      child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2))
                                  : const Text('SIMPAN'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.info_outline,
                                  size: 14, color: AppTheme.primaryColor),
                              SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'PPN 11% standar Indonesia. Ubah jika diperlukan. Nilai PPN disimpan saat transaksi, jadi riwayat lama tidak berubah meskipun Anda mengubah persentase.',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.textLightColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'Catatan: PPN dihitung dari (subtotal − diskon) di setiap transaksi. '
              'Diskon diinput manual oleh kasir di dialog pembayaran.',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textLightColor,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          const SizedBox(height: 24),
          _sectionHeader('Akun'),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Row(
              children: [
                Icon(Icons.construction, color: AppTheme.textLightColor),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Pengaturan akun akan tersedia di update berikutnya.',
                    style: TextStyle(
                        fontSize: 12, color: AppTheme.textLightColor),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          color: AppTheme.textLightColor,
        ),
      ),
    );
  }
}