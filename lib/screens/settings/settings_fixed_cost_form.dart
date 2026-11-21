part of '../settings_screen.dart';

class _FixedCostSection extends StatefulWidget {
  const _FixedCostSection();

  @override
  State<_FixedCostSection> createState() => _FixedCostSectionState();
}

class _FixedCostSectionState extends State<_FixedCostSection> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    FixedCostSettings.instance.monthly.addListener(_onChanged);
    _syncText();
  }

  @override
  void dispose() {
    FixedCostSettings.instance.monthly.removeListener(_onChanged);
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (!mounted || _focus.hasFocus) return;
    _syncText();
  }

  void _syncText() {
    final text = FixedCostSettings.instance.currentMonthly.toString();
    if (_controller.text != text) {
      _controller.text = text;
    }
  }

  Future<void> _save() async {
    final parsed = int.tryParse(_controller.text.trim());
    if (parsed == null || parsed < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Masukkan angka rupiah yang valid'),
          backgroundColor: AppTheme.dangerColor,
        ),
      );
      return;
    }
    setState(() => _saving = true);
    await FixedCostSettings.instance.setMonthly(parsed);
    if (!mounted) return;
    setState(() => _saving = false);
    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Biaya tetap disimpan'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionHeader('Biaya Tetap'),
        _card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Biaya tetap per bulan (gaji + sewa)',
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
                        controller: _controller,
                        focusNode: _focus,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: const InputDecoration(
                          prefixText: 'Rp ',
                          hintText: '30500000',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _saving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 18,
                        ),
                      ),
                      child: _saving
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
                          'Dipakai untuk titik impas di Laporan. Jangan dicatat juga sebagai pengeluaran harian, agar tidak terhitung dua kali.',
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
        ),
      ],
    );
  }
}