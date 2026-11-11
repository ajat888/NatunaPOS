import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/local_db.dart';
import 'report_service.dart';

class AiReportService {
  AiReportService._();
  static final AiReportService instance = AiReportService._();

  static const String _envApiUrl = String.fromEnvironment('API_BASE_URL');

  String get _apiBase {
    if (_envApiUrl.isNotEmpty) return _envApiUrl;
    if (kIsWeb) return Uri.base.origin;
    return '';
  }

  String? get _jwt => Supabase.instance.client.auth.currentSession?.accessToken;

  Future<String> analyze({
    required String pin,
    required DateTime from,
    required DateTime to,
    required ReportSummary summary,
  }) async {
    if (_apiBase.isEmpty) {
      throw Exception('API_BASE_URL belum dikonfigurasi. Hubungi developer.');
    }
    final jwt = _jwt;
    if (jwt == null) {
      throw Exception('Sesi tidak valid. Silakan login ulang.');
    }

    final start = DateTime(from.year, from.month, from.day);
    final end =
        DateTime(to.year, to.month, to.day).add(const Duration(days: 1));

    final products =
        await LocalDb.instance.getProductPerformanceBetween(start, end);
    final daily =
        await LocalDb.instance.getDailySalesBreakdown(start, end);

    final payload = {
      'pin': pin,
      'report': {
        'period': {'from': _fmtDate(from), 'to': _fmtDate(to)},
        'summary': {
          'total_sales': summary.totalSales,
          'total_transactions': summary.totalTransactions,
          'total_hpp': summary.totalHpp,
          'total_expenses': summary.totalExpenses,
          'gross_profit': summary.grossProfit,
          'net_profit': summary.netProfit,
          'void_count': summary.totalVoidCount,
          'void_amount':
              summary.totalVoidAmount + summary.totalVoidOpenOrderAmount,
          'cash_expected': summary.cashExpected,
        },
        'products': products,
        'daily': daily,
        'expenses': summary.expenses
            .map((e) => {
                  'item_name': e.itemName,
                  'category_name': e.categoryName,
                  'amount': e.amount,
                  'created_at': _fmtDate(e.createdAt),
                })
            .toList(),
        'voids': [
          ...summary.transactions.where((t) => t.isVoided).map((t) => {
                'total': t.total,
                'reason': t.voidReason ?? '',
                'voided_by': t.voidedBy ?? '',
                'voided_at': t.voidedAt != null ? _fmtDate(t.voidedAt!) : '',
              }),
          ...summary.voidedOpenOrders.map((v) => {
                'total': v.subtotal,
                'reason': v.voidReason,
                'voided_by': v.voidedBy,
                'voided_at': _fmtDate(v.voidedAt),
              }),
        ],
      },
    };

    http.Response resp;
    try {
      resp = await http
          .post(
            Uri.parse('$_apiBase/api/analyze'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $jwt',
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 90));
    } on TimeoutException {
      throw Exception(
          'Analisis memakan waktu terlalu lama. Coba lagi dengan periode lebih singkat.');
    } on http.ClientException catch (e) {
      throw Exception('Tidak dapat terhubung ke server: ${e.message}');
    }

    Map<String, dynamic> decoded;
    try {
      decoded = jsonDecode(resp.body) as Map<String, dynamic>;
    } catch (_) {
      throw Exception('Respons server tidak valid (HTTP ${resp.statusCode})');
    }

    if (resp.statusCode == 200) {
      final analysis = (decoded['analysis'] as String?)?.trim();
      if (analysis == null || analysis.isEmpty) {
        throw Exception('Respons analisis kosong.');
      }
      return analysis;
    }
    throw Exception(
        (decoded['error'] as String?) ?? 'Gagal (HTTP ${resp.statusCode})');
  }

  String _fmtDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}