import 'package:flutter/material.dart';
import '../core/theme.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Riwayat Transaksi'),
        automaticallyImplyLeading: false,
      ),
      body: const Center(
        child: Text(
          'Belum ada riwayat transaksi.',
          style: TextStyle(color: AppTheme.textLightColor),
        ),
      ),
    );
  }
}