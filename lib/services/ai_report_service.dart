import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/local_db.dart';
import '../core/fixed_cost_settings.dart';
import 'break_even_math.dart';
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

    final cutoff = _todayCutoff(end);
    final comparison = await _comparisonPayload(start, end, cutoff);
    final hourly =
        await LocalDb.instance.getHourlySalesBreakdown(start, end);

        final monthly = FixedCostSettings.instance.currentMonthly;
    final breakEven =
        monthly > 0 ? await _breakEvenPayload(monthly, summary) : null;
    final payload = {
      'pin': pin,
      'report': {
        'period': {
          'from': _fmtDate(from),
          'to': _fmtDate(to),
          'partial_until': cutoff != null ? _fmtHm(cutoff) : null,
        },
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
        'break_even': breakEven,
        'comparison': comparison,
        'hourly': hourly,
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

  Future<Map<String, dynamic>?> _breakEvenPayload(
    int monthly,
    ReportSummary summary,
  ) async {
    final result = <String, dynamic>{
      'monthly': monthly,
      ...BreakEvenMath.periodView(monthly: monthly, summary: summary),
    };
    final now = DateTime.now();
    final isCurrentMonth =
        summary.to.year == now.year && summary.to.month == now.month;
    if (isCurrentMonth) {
      final mtd = await ReportService.instance.buildReport(
        from: DateTime(summary.to.year, summary.to.month, 1),
        to: summary.to,
      );
      result.addAll(BreakEvenMath.remainingView(monthly: monthly, mtd: mtd));
    }
    return result;
  } 
  
  // Jika periode mencakup hari ini, kembalikan waktu sekarang agar
  // periode pembanding bisa dibatasi pada jam yang sama.
  DateTime? _todayCutoff(DateTime end) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final lastDay = end.subtract(const Duration(days: 1));
    return lastDay.isBefore(todayStart) ? null : now;
  }

  // Periode pembanding: jendela dengan panjang sama tepat sebelum periode.
  Future<Map<String, dynamic>> _comparisonPayload(
    DateTime start,
    DateTime end,
    DateTime? cutoff,
  ) async {
    final days = end.difference(start).inDays;
    final prevStart = DateTime(start.year, start.month, start.day - days);
    final prevEnd = cutoff != null
        ? DateTime(cutoff.year, cutoff.month, cutoff.day - days,
            cutoff.hour, cutoff.minute, cutoff.second)
        : DateTime(end.year, end.month, end.day - days);
    final db = LocalDb.instance;
    final sales = await db.getSalesSummaryBetween(prevStart, prevEnd);
    final hpp = await db.getHppBetween(prevStart, prevEnd);
    final expenses = await db.getExpenseSummaryBetween(prevStart, prevEnd);
    final voids =
        await db.getVoidTransactionsSummaryBetween(prevStart, prevEnd);
    return {
      'period': {
        'from': _fmtDate(prevStart),
        'to': cutoff != null
            ? _fmtDate(prevEnd)
            : _fmtDate(prevEnd.subtract(const Duration(days: 1))),
        'until_time': cutoff != null ? _fmtHm(prevEnd) : null,
      },
      'total_sales': sales['total'] ?? 0,
      'total_transactions': sales['count'] ?? 0,
      'total_hpp': hpp,
      'total_expenses': expenses['total'] ?? 0,
      'void_amount': voids['total'] ?? 0,
    };
  }

  String _fmtHm(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:'
      '${d.minute.toString().padLeft(2, '0')}';

  String _fmtDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}