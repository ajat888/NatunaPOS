part of '../pos_screen.dart';

class _VoidOpenOrderDialog extends StatefulWidget {
  final OpenOrder order;
  const _VoidOpenOrderDialog({required this.order});

  @override
  State<_VoidOpenOrderDialog> createState() => _VoidOpenOrderDialogState();
}

class _VoidOpenOrderDialogState extends State<_VoidOpenOrderDialog> {
  final _controller = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _valid => _controller.text.trim().length >= 5;

  Future<void> _submit() async {
    final reason = _controller.text.trim();
    if (reason.length < 5) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await SupabaseService().voidOpenOrder(
        orderKey: widget.order.orderKey,
        reason: reason,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.decimalPattern('id');
    final screenW = MediaQuery.sizeOf(context).width;
    final contentW = screenW < 528 ? screenW - 88 : 420.0;

    return AlertDialog(
      scrollable: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      title: const Text('Void Pesanan'),
      content: SizedBox(
        width: contentW,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _row('Pesanan', widget.order.label),
            const SizedBox(height: 4),
            _row('Total', 'Rp ${fmt.format(widget.order.total)}'),
            const SizedBox(height: 4),
            _row('Jumlah Item', '${widget.order.itemCount}'),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              minLines: 3,
              maxLines: 5,
              enabled: !_saving,
              decoration: const InputDecoration(
                labelText: 'Alasan Void',
                hintText: 'Contoh: salah input produk',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.06),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'Pesanan akan dihapus dari meja & tidak masuk omzet. Data tetap tercatat di Riwayat Void untuk audit.',
                style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.textLightColor,
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!,
                  style: const TextStyle(
                      color: AppTheme.dangerColor, fontSize: 12)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('BATAL'),
        ),
        ElevatedButton(
          style:
              ElevatedButton.styleFrom(backgroundColor: AppTheme.dangerColor),
          onPressed: (_valid && !_saving) ? _submit : null,
          child: _saving
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
              : const Text('VOID'),
        ),
      ],
    );
  }

  Widget _row(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 12, color: AppTheme.textLightColor)),
        Text(value,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.textColor)),
      ],
    );
  }
}