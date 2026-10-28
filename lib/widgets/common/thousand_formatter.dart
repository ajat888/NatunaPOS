// lib/widgets/common/thousand_formatter.dart
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class ThousandFormatter extends TextInputFormatter {
  final NumberFormat _formatter = NumberFormat.decimalPattern('id');

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue;
    final cleanText = newValue.text.replaceAll('.', '');
    if (cleanText.isEmpty) return newValue.copyWith(text: '');
    final int? value = int.tryParse(cleanText);
    if (value == null) return oldValue;
    final String formatted = _formatter.format(value);
    return TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length));
  }
}