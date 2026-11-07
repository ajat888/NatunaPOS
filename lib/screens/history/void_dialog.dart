part of '../history_screen.dart';

class _VoidDialog extends StatefulWidget {
  final Transaction transaction;
  const _VoidDialog({required this.transaction});

  @override
  State<_VoidDialog> createState() => _VoidDialogState();
}

class _VoidDialogState extends State<_VoidDialog> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _valid => _controller.text.trim().length >= 5;

  void _submit() {
    final reason = _controller.text.trim();
    if (reason.length < 5) {
      setState(() => _error = 'Alasan minimal 5 karakter');
      return;
    }
    Navigator.pop(context, reason);
  }

  @override
  Widget build(BuildContext context) {
    final tx = widget.transaction;
    final fmt = NumberFormat.decimalPattern('id');
    final dateFmt = DateFormat('dd/MM/yyyy HH:mm');
    final screenW = MediaQuery.sizeOf(context).width;
    final contentW = screenW < 528 ? screenW - 88 : 420.0;

    return AlertDialog(
      scrollable: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      title: const Text('Void Transaksi'),
      content: SizedBox(
        width: contentW,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _row('Total', 'Rp ${fmt.format(tx.total)}'),
            const SizedBox(height: 4),
            _row('Waktu', dateFmt.format(tx.createdAt)),
            const SizedBox(height: 4),
            _row('Item', '${tx.itemCount}'),
            if (tx.parentOrderKey != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Catatan: Item yang sudah dibayar di split sebelumnya tidak dikembalikan.',
                  style: TextStyle(
                      fontSize: 11, color: AppTheme.textLightColor),
                ),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              minLines: 3,
              maxLines: 5,
              decoration: InputDecoration(
                labelText: 'Alasan Void',
                hintText: 'Contoh: salah input produk',
                errorText: _error,
              ),
              onChanged: (_) {
                setState(() {
                  if (_error != null) _error = null;
                });
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('BATAL'),
        ),
        ElevatedButton(
          style:
              ElevatedButton.styleFrom(backgroundColor: AppTheme.dangerColor),
          onPressed: _valid ? _submit : null,
          child: const Text('VOID'),
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