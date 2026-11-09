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
    
    // Logika memperbaiki posisi kursor
    final int cursorPosition = newValue.selection.end;
    int digitCountBeforeCursor = 0;
    
    // Hitung berapa digit (angka) sebelum kursor berada
    for (int i = 0; i < cursorPosition && i < newValue.text.length; i++) {
      if (newValue.text[i] != '.') {
        digitCountBeforeCursor++;
      }
    }

    // Cari posisi index di teks yang baru diformat berdasarkan jumlah digit tadi
    int newCursorPosition = 0;
    int currentDigitCount = 0;
    for (int i = 0; i < formatted.length; i++) {
      if (formatted[i] != '.') {
        currentDigitCount++;
      }
      if (currentDigitCount == digitCountBeforeCursor) {
        newCursorPosition = i + 1;
        break;
      }
    }

    if (digitCountBeforeCursor == 0) newCursorPosition = 0;

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: newCursorPosition),
    );
  }
}