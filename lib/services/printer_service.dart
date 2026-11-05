import 'dart:io';
import 'package:flutter/material.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:intl/intl.dart'; // <-- TAMBAHAN
import 'package:image/image.dart' as img; // <-- TAMBAHAN
import '../models/transaction.dart';
import 'app_settings.dart';

part 'printer_receipt.dart'; // Pastikan file ini ada di folder yang sama

class PrinterService {
  PrinterService._();
  static final PrinterService instance = PrinterService._();

  Future<bool> get isConnected => PrintBluetoothThermal.connectionStatus;

  Future<List<BluetoothInfo>> getBondedDevices() async {
    return await PrintBluetoothThermal.pairedBluetooths;
  }

  Future<bool> connect(String macAddress) async {
    try {
      return await PrintBluetoothThermal.connect(macPrinterAddress: macAddress);
    } catch (e) {
      debugPrint('Connect Bluetooth failed: $e');
      return false;
    }
  }

  Future<void> disconnect() async {
    try {
      await PrintBluetoothThermal.disconnect;
    } catch (e) {
      debugPrint('Disconnect Bluetooth failed: $e');
    }
  }

  Future<bool> printReceipt(Transaction tx) async {
    final isConn = await isConnected;
    if (!isConn) {
      final mac = AppSettings.instance.printerMac.value;
      if (mac != null && mac.isNotEmpty) {
        final success = await connect(mac);
        if (!success) return false;
      } else {
        return false;
      }
    }

    try {
      final profile = await CapabilityProfile.load();
      final generator = Generator(PaperSize.mm58, profile);
      final bytes = await _generateReceiptBytes(tx, generator);

      if (Platform.isAndroid) {
        final res = await PrintBluetoothThermal.writeBytes(bytes);
        return res;
      }
      return false;
    } catch (e) {
      debugPrint('Print receipt failed: $e');
      return false;
    }
  }

  Future<bool> printTest() async {
    final now = DateTime.now();
    final dummyTx = Transaction(
      id: 9999,
      total: 35000,
      subtotal: 35000,
      billDiscount: 0,
      discountType: 'nominal',
      discountValue: 0,
      taxRate: 0,
      taxAmount: 0,
      createdAt: now,
      isSynced: true,
      items: [
        TransactionItem(
          id: 1,
          transactionId: 9999,
          productId: 1,
          productName: 'Ayam Bakar Lalapan',
          price: 35000,
          hpp: 15000,
          qty: 1,
        )
      ],
      cashReceived: 50000,
      changeAmount: 15000,
      tableNumber: 'M-08',
      orderType: 'dine_in',
    );
    return printReceipt(dummyTx);
  }
}