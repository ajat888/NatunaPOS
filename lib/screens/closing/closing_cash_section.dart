part of '../closing_screen.dart';

class _ClosingCashSection extends StatelessWidget {
  final TextEditingController cashController;
  final TextEditingController noteController;
  final int cashExpected;
  final int cashDifference;
  final bool logoutAfter;
  final ValueChanged<bool> onLogoutChanged;
  final VoidCallback onCashChanged;
  final VoidCallback onSubmit;
  final bool isSaving;

  const _ClosingCashSection({
    required this.cashController,
    required this.noteController,
    required this.cashExpected,
    required this.cashDifference,
    required this.logoutAfter,
    required this.onLogoutChanged,
    required this.onCashChanged,
    required this.onSubmit,
    required this.isSaving,
  });

  Color _diffColor() {
    if (cashDifference == 0) return Colors.green.shade700;
    if (cashDifference < 0) return AppTheme.dangerColor;
    return Colors.orange.shade800;
  }

  Color _diffBg() {
    if (cashDifference == 0) return Colors.green.shade50;
    if (cashDifference < 0) return AppTheme.dangerColor.withOpacity(0.08);
    return Colors.orange.shade50;
  }

  Color _diffBorder() {
    if (cashDifference == 0) return Colors.green.shade300;
    if (cashDifference < 0) return AppTheme.dangerColor.withOpacity(0.4);
    return Colors.orange.shade300;
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.decimalPattern('id');
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'CASH FISIK',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: AppTheme.textLightColor,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: cashController,
            keyboardType: TextInputType.number,
            inputFormatters: [ThousandFormatter()],
            decoration: InputDecoration(
              labelText: 'Cash Fisik Aktual',
              prefixText: 'Rp ',
              helperText: 'Seharusnya: Rp ${fmt.format(cashExpected)}',
            ),
            onChanged: (_) => onCashChanged(),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _diffBg(),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _diffBorder()),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  cashDifference == 0
                      ? 'Cocok'
                      : (cashDifference > 0 ? 'Lebih' : 'Kurang'),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _diffColor(),
                  ),
                ),
                Text(
                  'Rp ${fmt.format(cashDifference.abs())}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _diffColor(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: noteController,
            minLines: 2,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Catatan (opsional)',
              hintText: 'Contoh: ada selisih karena tip',
            ),
          ),
          const SizedBox(height: 12),
          CheckboxListTile(
            value: logoutAfter,
            onChanged:
                isSaving ? null : (v) => onLogoutChanged(v ?? false),
            title: const Text(
              'Logout setelah closing',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppTheme.textColor,
              ),
            ),
            subtitle: const Text(
              'Hari kerja selesai — user akan keluar dari aplikasi.',
              style: TextStyle(fontSize: 11),
            ),
            activeColor: AppTheme.primaryColor,
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: isSaving ? null : onSubmit,
            icon: const Icon(Icons.lock_outline),
            label: Text(isSaving ? 'MENYIMPAN...' : 'TUTUP BUKU'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.dangerColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 18),
            ),
          ),
        ],
      ),
    );
  }
}