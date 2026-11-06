part of '../settings_screen.dart';

class _TaxSection extends StatefulWidget {
  const _TaxSection();

  @override
  State<_TaxSection> createState() => _TaxSectionState();
}

class _TaxSectionState extends State<_TaxSection> {
  final _rateController = TextEditingController();
  final _rateFocus = FocusNode();
  bool _savingRate = false;

  @override
  void initState() {
    super.initState();
    TaxSettings.instance.enabled.addListener(_onTaxChanged);
    TaxSettings.instance.rate.addListener(_onRateChanged);
    _syncRateText();
  }

  @override
  void dispose() {
    TaxSettings.instance.enabled.removeListener(_onTaxChanged);
    TaxSettings.instance.rate.removeListener(_onRateChanged);
    _rateController.dispose();
    _rateFocus.dispose();
    super.dispose();
  }

  void _onTaxChanged() {
    if (mounted) setState(() {});
  }

  void _onRateChanged() {
    if (!mounted) return;
    if (_rateFocus.hasFocus) return;
    _syncRateText();
  }

  void _syncRateText() {
    final r = TaxSettings.instance.currentRate;
    final text = r == r.roundToDouble() ? r.toInt().toString() : r.toString();
    if (_rateController.text != text) {
      _rateController.text = text;
    }
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
    final display = parsed == parsed.roundToDouble()
        ? parsed.toInt().toString()
        : parsed.toString();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Persentase PPN disimpan: $display%'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final enabled = TaxSettings.instance.isEnabled;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionHeader('Pajak & Diskon'),
        _card(
          child: Column(
            children: [
              SwitchListTile.adaptive(
                title: const Text('Aktifkan PPN'),
                subtitle: const Text(
                  'PPN ditambahkan ke total setiap transaksi',
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
                                decimal: true,
                              ),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'[0-9.,]'),
                                ),
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
                                horizontal: 20,
                                vertical: 18,
                              ),
                            ),
                            child: _savingRate
                                ? const SizedBox(
                                    height: 16,
                                    width: 16,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
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
                            Icon(
                              Icons.info_outline,
                              size: 14,
                              color: AppTheme.primaryColor,
                            ),
                            SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Nilai PPN disimpan saat transaksi. Riwayat lama tidak berubah meskipun persentase diubah.',
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
      ],
    );
  }
}