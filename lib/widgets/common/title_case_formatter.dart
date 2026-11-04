// lib/widgets/common/title_case_formatter.dart
import 'package:flutter/services.dart';

class TitleCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue;

    final text = newValue.text;
    final buffer = StringBuffer();
    bool capitalizeNext = true;

    for (int i = 0; i < text.length; i++) {
      final char = text[i];
      if (char == ' ') {
        capitalizeNext = true;
        buffer.write(char);
      } else {
        if (capitalizeNext) {
          buffer.write(char.toUpperCase());
          capitalizeNext = false;
        } else {
          buffer.write(char);
        }
      }
    }

    final formattedText = buffer.toString();
    
    // Pertahankan posisi kursor jika panjang teks tidak berubah
    if (formattedText.length == text.length) {
      return TextEditingValue(
        text: formattedText,
        selection: newValue.selection,
      );
    }
    
    // Jika panjang berubah (kasus langka), kembalikan kursor ke akhir
    return TextEditingValue(
      text: formattedText,
      selection: TextSelection.collapsed(offset: formattedText.length),
    );
  }
}