// lib/screens/pos/pos_payment_dialog.dart
part of '../pos_screen.dart';

class _PaymentDialog extends StatefulWidget {
  final OpenOrder order;
  final SupabaseService service;
  final Future<void> Function() onSuccess;

  const _PaymentDialog({
    required this.order,
    required this.service,
    required this.onSuccess,
  });

  @override
  State<_PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<_PaymentDialog> {
  final _controller = TextEditingController();
  final _formatter = NumberFormat.decimalPattern('id');
  bool _saving = false;
  String? _error;

  int get _cashReceived {
    final clean = _controller.text.replaceAll('.', '').trim();
    return int.tryParse(clean) ?? 0;
  }

  int get _change => _cashReceived - widget.order.total;
  bool get _canPay => _cashReceived >= widget.order.total;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _setAmount(int amount) {
    setState(() {
      _controller.text = _formatter.format(amount);
    });
  }

  Future<void> _pay() async {
    if (!_canPay || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.service.payOpenOrder(
        orderKey: widget.order.orderKey,
        cashReceived: _cashReceived,
        changeAmount: _change,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      await widget.onSuccess();
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
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      title: const Text('Pembayaran'),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${widget.order.label} • ${widget.order.itemCount} item',
                    style: const TextStyle(
                        color: AppTheme.textLightColor, fontSize: 12)),
                Text('Total',
                    style: const TextStyle(
                        color: AppTheme.textLightColor, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: Text('Rp ${_formatter.format(widget.order.total)}',
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textColor)),
            ),
            const SizedBox(height: 16),
            const Text('Uang Diterima',
                style: TextStyle(
                    fontSize: 12, color: AppTheme.textLightColor)),
            const SizedBox(height: 6),
            TextField(
              controller: _controller,
              keyboardType: TextInputType.number,
              inputFormatters: [ThousandFormatter()],
              decoration: const InputDecoration(prefixText: 'Rp '),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _setAmount(widget.order.total),
                    child: const Text('UANG PAS'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _setAmount(50000),
                    child: const Text('50.000'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _setAmount(100000),
                    child: const Text('100.000'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _canPay
                    ? Colors.green.shade50
                    : AppTheme.dangerColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: _canPay
                        ? Colors.green.shade300
                        : AppTheme.dangerColor.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_canPay ? 'Kembalian' : 'Kurang',
                      style: TextStyle(
                          color: _canPay
                              ? Colors.green.shade900
                              : AppTheme.dangerColor,
                          fontWeight: FontWeight.w600)),
                  Text(
                      'Rp ${_formatter.format(_canPay ? _change : -_change)}',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: _canPay
                              ? Colors.green.shade900
                              : AppTheme.dangerColor)),
                ],
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!,
                  style: const TextStyle(
                      color: AppTheme.dangerColor, fontSize: 12)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('BATAL'),
        ),
        ElevatedButton(
          onPressed: _canPay && !_saving ? _pay : null,
          child: _saving
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