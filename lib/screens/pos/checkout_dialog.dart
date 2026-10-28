part of '../pos_screen.dart';

class _CheckoutDialog extends StatefulWidget {
  final List<TransactionLine> lines;
  final int total;
  final SupabaseService service;
  final VoidCallback onSuccess;

  const _CheckoutDialog({
    required this.lines,
    required this.total,
    required this.service,
    required this.onSuccess,
  });

  @override
  State<_CheckoutDialog> createState() => _CheckoutDialogState();
}

class _CheckoutDialogState extends State<_CheckoutDialog> {
  bool _isSaving = false;
  String? _errorMessage;

  Future<void> _save() async {
    if (_isSaving) return;
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });
    try {
      await widget.service.saveTransaction(
        lines: widget.lines,
        total: widget.total,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onSuccess();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _errorMessage =
            'Gagal menyimpan transaksi: ${e.toString().replaceAll('Exception: ', '')}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final formatCurrency = NumberFormat.decimalPattern('id');
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      title: const Text('Konfirmasi Pembayaran'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Total tagihan: Rp ${formatCurrency.format(widget.total)}',
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textColor),
            ),
            const SizedBox(height: 8),
            Text('${widget.lines.length} jenis produk',
                style: const TextStyle(color: AppTheme.textLightColor)),
            const SizedBox(height: 16),
            const Text('Lanjutkan proses pembayaran?',
                style: TextStyle(color: AppTheme.textColor)),
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: AppTheme.dangerColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8)),
                child: Text(_errorMessage!,
                    style: const TextStyle(
                        color: AppTheme.dangerColor, fontSize: 12)),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('BATAL',
              style: TextStyle(color: AppTheme.textLightColor)),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
              : const Text('BAYAR'),
        ),
      ],
    );
  }
}