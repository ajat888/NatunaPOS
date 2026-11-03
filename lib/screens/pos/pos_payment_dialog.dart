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

  // Diskon bill
  int _billDiscount = 0;
  String _discountType = 'nominal';
  int _discountValue = 0;

  // PPN
  bool _applyTax = false;
  double _taxRate = 0;

  @override
  void initState() {
    super.initState();
    _applyTax = TaxSettings.instance.isEnabled;
    _taxRate = TaxSettings.instance.currentRate;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int get _subtotal => widget.order.subtotal;
  int get _dasarPajak => _subtotal - _billDiscount;
  int get _taxAmount =>
      _applyTax && _taxRate > 0 ? (_dasarPajak * _taxRate / 100).round() : 0;
  int get _grandTotal => _dasarPajak + _taxAmount;

  int get _cashReceived {
    final clean = _controller.text.replaceAll('.', '').trim();
    return int.tryParse(clean) ?? 0;
  }

  int get _change => _cashReceived - _grandTotal;
  bool get _canPay => _cashReceived >= _grandTotal;

  void _setAmount(int amount) {
    setState(() {
      _controller.text = _formatter.format(amount);
    });
  }

  Future<void> _editDiscount() async {
    final result = await showDialog<DiscountResult>(
      context: context,
      builder: (_) => _DiscountDialog(
        subtotal: _subtotal,
        currentBillDiscount: _billDiscount,
        currentType: _discountType,
        currentValue: _discountValue,
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _billDiscount = result.billDiscount;
        _discountType = result.discountType;
        _discountValue = result.discountValue;
      });
    }
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
        billDiscount: _billDiscount,
        discountType: _discountType,
        discountValue: _discountValue,
        taxRate: _applyTax ? _taxRate : 0,
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
    final screenWidth = MediaQuery.sizeOf(context).width;
    final contentWidth = screenWidth < 528 ? screenWidth - 88 : 440.0;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      title: const Text('Pembayaran'),
      content: SizedBox(
        width: contentWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(widget.order.label,
                    style: const TextStyle(
                        color: AppTheme.textLightColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
                Text('${widget.order.itemCount} item',
                    style: const TextStyle(
                        color: AppTheme.textLightColor, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxHeight: 130),
              decoration: BoxDecoration(
                color: AppTheme.backgroundColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.all(12),
                itemCount: widget.order.items.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 12, color: Color(0xFFE2E8F0)),
                itemBuilder: (context, i) {
                  final item = widget.order.items[i];
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          '${item.productName} x${item.qty}',
                          style: const TextStyle(
                              fontSize: 13, color: AppTheme.textColor),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        'Rp ${_formatter.format(item.subtotal)}',
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.textColor),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            // Breakdown
            _breakdownRow('Subtotal', 'Rp ${_formatter.format(_subtotal)}'),
            const SizedBox(height: 6),
            InkWell(
              onTap: _editDiscount,
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(
                          _billDiscount > 0 ? 'Diskon' : 'Tambah Diskon',
                          style: TextStyle(
                            fontSize: 12,
                            color: _billDiscount > 0
                                ? AppTheme.dangerColor
                                : AppTheme.primaryColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          _billDiscount > 0
                              ? Icons.edit_outlined
                              : Icons.add_circle_outline,
                          size: 13,
                          color: _billDiscount > 0
                              ? AppTheme.dangerColor
                              : AppTheme.primaryColor,
                        ),
                      ],
                    ),
                    Text(
                      _billDiscount > 0
                          ? '−Rp ${_formatter.format(_billDiscount)}'
                          : 'Rp 0',
                      style: TextStyle(
                        fontSize: _billDiscount > 0 ? 13 : 12,
                        fontWeight: FontWeight.w600,
                        color: _billDiscount > 0
                            ? AppTheme.dangerColor
                            : AppTheme.textLightColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_applyTax && _taxRate > 0) ...[
              const SizedBox(height: 6),
              _breakdownRow(
                'PPN ${_taxRate == _taxRate.roundToDouble() ? _taxRate.toInt() : _taxRate}%',
                'Rp ${_formatter.format(_taxAmount)}',
              ),
            ],
            const Divider(height: 16, color: Color(0xFFE2E8F0)),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total',
                    style: TextStyle(
                        color: AppTheme.textLightColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
                Text('Rp ${_formatter.format(_grandTotal)}',
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textColor)),
              ],
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
                    onPressed: () => _setAmount(_grandTotal),
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

  Widget _breakdownRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(
                color: AppTheme.textLightColor, fontSize: 12)),
        Text(value,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppTheme.textColor)),
      ],
    );
  }
}