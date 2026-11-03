// lib/screens/pos/pos_discount_dialog.dart
part of '../pos_screen.dart';

class DiscountResult {
  final int billDiscount;
  final String discountType;
  final int discountValue;
  const DiscountResult({
    required this.billDiscount,
    required this.discountType,
    required this.discountValue,
  });
}

class _DiscountDialog extends StatefulWidget {
  final int subtotal;
  final int currentBillDiscount;
  final String currentType;
  final int currentValue;

  const _DiscountDialog({
    required this.subtotal,
    required this.currentBillDiscount,
    required this.currentType,
    required this.currentValue,
  });

  @override
  State<_DiscountDialog> createState() => _DiscountDialogState();
}

class _DiscountDialogState extends State<_DiscountDialog> {
  late String _type;
  late final TextEditingController _controller;
  final _formatter = NumberFormat.decimalPattern('id');
  String? _error;

  @override
  void initState() {
    super.initState();
    _type = widget.currentType;
    if (_type == 'nominal') {
      _controller = TextEditingController(
        text: widget.currentBillDiscount > 0
            ? _formatter.format(widget.currentBillDiscount)
            : '',
      );
    } else {
      _controller = TextEditingController(
        text: widget.currentValue > 0 ? widget.currentValue.toString() : '',
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int get _rawInput {
    if (_type == 'nominal') {
      return int.tryParse(_controller.text.replaceAll('.', '').trim()) ?? 0;
    }
    return int.tryParse(_controller.text.trim()) ?? 0;
  }

  int get _computedDiscount {
    final raw = _rawInput;
    int d;
    if (_type == 'nominal') {
      d = raw;
    } else {
      d = (widget.subtotal * raw / 100).round();
    }
    return d.clamp(0, widget.subtotal);
  }

  int get _finalTotal => widget.subtotal - _computedDiscount;

  void _setType(String t) {
    if (_type == t) return;
    setState(() {
      _type = t;
      _controller.clear();
      _error = null;
    });
  }

  void _apply() {
    setState(() => _error = null);
    final raw = _rawInput;

    if (raw < 0) {
      setState(() => _error = 'Nilai tidak valid');
      return;
    }
    if (_type == 'nominal' && raw > widget.subtotal) {
      setState(() => _error = 'Diskon tidak boleh melebihi subtotal');
      return;
    }
    if (_type == 'percent' && raw > 100) {
      setState(() => _error = 'Persen maksimal 100');
      return;
    }

    Navigator.pop(
      context,
      DiscountResult(
        billDiscount: _computedDiscount,
        discountType: _type,
        discountValue: raw,
      ),
    );
  }

  void _clear() {
    Navigator.pop(
      context,
      const DiscountResult(
        billDiscount: 0,
        discountType: 'nominal',
        discountValue: 0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      title: const Text('Atur Diskon'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: _modeButton('Nominal', 'nominal', 'Rp'),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _modeButton('Persen', 'percent', '%'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              keyboardType: TextInputType.number,
              inputFormatters: _type == 'nominal'
                  ? [ThousandFormatter()]
                  : [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: _type == 'nominal' ? 'Nominal Diskon' : 'Persen Diskon',
                prefixText: _type == 'nominal' ? 'Rp ' : null,
                suffixText: _type == 'percent' ? ' %' : null,
                errorText: _error,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.backgroundColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  _row('Subtotal',
                      'Rp ${_formatter.format(widget.subtotal)}'),
                  const SizedBox(height: 6),
                  _row('Diskon',
                      '−Rp ${_formatter.format(_computedDiscount)}',
                      danger: _computedDiscount > 0),
                  const Divider(height: 16, color: Color(0xFFE2E8F0)),
                  _row(
                      'Total Setelah Diskon',
                      'Rp ${_formatter.format(_finalTotal)}',
                      bold: true),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _clear, child: const Text('HAPUS')),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('BATAL'),
        ),
        ElevatedButton(onPressed: _apply, child: const Text('TERAPKAN')),
      ],
    );
  }

  Widget _modeButton(String label, String value, String hint) {
    final selected = _type == value;
    return InkWell(
      onTap: () => _setType(value),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.primaryColor.withOpacity(0.1)
              : AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? AppTheme.primaryColor : const Color(0xFFE2E8F0),
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: selected ? AppTheme.primaryColor : AppTheme.textColor,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'dalam $hint',
              style: TextStyle(
                fontSize: 11,
                color: selected
                    ? AppTheme.primaryColor
                    : AppTheme.textLightColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value,
      {bool bold = false, bool danger = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(
                color: AppTheme.textLightColor, fontSize: 13)),
        Text(
          value,
          style: TextStyle(
            fontWeight: bold ? FontWeight.bold : FontWeight.w600,
            fontSize: bold ? 15 : 13,
            color: danger
                ? AppTheme.dangerColor
                : (bold ? AppTheme.primaryColor : AppTheme.textColor),
          ),
        ),
      ],
    );
  }
}