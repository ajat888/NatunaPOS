// lib/screens/reports_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../core/theme.dart';
import '../models/transaction.dart';
import '../services/report_service.dart';
import '../services/pin_service.dart';
import '../services/ai_report_service.dart';

part 'reports/reports_filter_card.dart';
part 'reports/reports_summary_cards.dart';
part 'reports/reports_lists.dart';
part 'reports/reports_pin_gate.dart';
part 'reports/reports_ai_view.dart';
part 'reports/reports_chart.dart';
part 'reports/reports_top_products.dart';

enum ReportPreset { today, yesterday, last7, last30, custom }

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  DateTime _from = _todayStart();
  DateTime _to = _todayStart();
  ReportPreset _preset = ReportPreset.today;
  ReportSummary? _summary;
  bool _isLoading = true;

  bool _pinGateLoading = true;
  String? _pinGateError;
  String? _verifiedPin;
  bool _aiLoading = false;

  static DateTime _todayStart() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  @override
  void initState() {
    super.initState();
    unawaited(_checkPinStatus());
  }

  Future<void> _checkPinStatus() async {
    setState(() {
      _pinGateLoading = true;
      _pinGateError = null;
    });
    try {
      final status = await PinService.instance.getStatus();
      if (!mounted) return;
      setState(() {
        _pinGateLoading = false;
      });
      unawaited(_showPinDialog(isSetup: !status.hasPin));
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceAll('Exception: ', '');
      setState(() {
        _pinGateLoading = false;
        _pinGateError = msg.isEmpty
            ? 'Halaman Laporan memerlukan koneksi internet. Periksa jaringan Anda.'
            : msg;
      });
    }
  }

  Future<void> _showPinDialog({required bool isSetup}) async {
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _PinGateDialog(
        isSetup: isSetup,
        onVerify: PinService.instance.verifyPin,
        onSetup: PinService.instance.setPin,
        onReset: PinService.instance.resetPin,
      ),
    );
    if (!mounted) return;
    if (result == null) {
      Navigator.pop(context);
      return;
    }
    setState(() => _verifiedPin = result);
    unawaited(_load());
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final s = await ReportService.instance.buildReport(from: _from, to: _to);
      if (!mounted) return;
      setState(() {
        _summary = s;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gagal memuat laporan'),
          backgroundColor: AppTheme.dangerColor,
        ),
      );
    }
  }

  void _applyPreset(ReportPreset p) {
    final today = _todayStart();
    DateTime from;
    DateTime to;
    switch (p) {
      case ReportPreset.today:
        from = today;
        to = today;
        break;
      case ReportPreset.yesterday:
        from = today.subtract(const Duration(days: 1));
        to = from;
        break;
      case ReportPreset.last7:
        from = today.subtract(const Duration(days: 6));
        to = today;
        break;
      case ReportPreset.last30:
        from = today.subtract(const Duration(days: 29));
        to = today;
        break;
      case ReportPreset.custom:
        return;
    }
    setState(() {
      _preset = p;
      _from = from;
      _to = to;
    });
    unawaited(_load());
  }

  Future<void> _pickFrom() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _from,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked == null) return;
    final newFrom = DateTime(picked.year, picked.month, picked.day);
    var newTo = _to;
    if (newFrom.isAfter(newTo)) newTo = newFrom;
    setState(() {
      _from = newFrom;
      _to = newTo;
      _preset = ReportPreset.custom;
    });
    await _load();
  }

  Future<void> _pickTo() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _to,
      firstDate: _from,
      lastDate: DateTime.now(),
    );
    if (picked == null) return;
    setState(() {
      _to = DateTime(picked.year, picked.month, picked.day);
      _preset = ReportPreset.custom;
    });
    await _load();
  }

  Future<void> _openAIAnalysis() async {
    final summary = _summary;
    final pin = _verifiedPin;
    if (summary == null || pin == null || _aiLoading) return;
    setState(() => _aiLoading = true);
    try {
      final analysis = await AiReportService.instance.analyze(
        pin: pin,
        from: _from,
        to: _to,
        summary: summary,
      );
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _AiAnalysisPage(
            analysis: analysis,
            from: _from,
            to: _to,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceAll('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg.isEmpty ? 'Gagal menganalisis laporan' : msg),
          backgroundColor: AppTheme.dangerColor,
        ),
      );
    } finally {
      if (mounted) setState(() => _aiLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_pinGateLoading) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(title: const Text('Laporan')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_pinGateError != null) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Kembali',
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text('Laporan'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.wifi_off,
                    size: 48, color: AppTheme.dangerColor),
                const SizedBox(height: 16),
                Text(
                  _pinGateError!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.textColor),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: _checkPinStatus,
                  child: const Text('Coba Lagi'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (_verifiedPin == null) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(title: const Text('Laporan')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Kembali',
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Laporan'),
        actions: [
          if (_summary != null && !_isLoading)
            IconButton(
              icon: _aiLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome),
              tooltip: 'Analisis AI',
              onPressed: _aiLoading ? null : _openAIAnalysis,
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Muat ulang',
            onPressed: _load,
          ),
        ],
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _load,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ReportsFilterCard(
                    from: _from,
                    to: _to,
                    preset: _preset,
                    onPreset: _applyPreset,
                    onPickFrom: _pickFrom,
                    onPickTo: _pickTo,
                  ),
                  const SizedBox(height: 16),
                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 48),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_summary == null)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 48),
                      child: Center(
                        child: Text(
                          'Tidak ada data.',
                          style: TextStyle(color: AppTheme.textLightColor),
                        ),
                      ),
                    )
                  else ...[
                    _ReportsSummaryCards(summary: _summary!),
                    if (_summary!.dailySales.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _ReportsChart(
                        dailySales: _summary!.dailySales,
                        from: _from,
                        to: _to,
                      ),
                    ],
                    const SizedBox(height: 16),
                    _ReportsTopProducts(topProducts: _summary!.topProducts),
                    const SizedBox(height: 16),
                    _ReportsLists(summary: _summary!),
                  ],
                ],
              ),
            ),
          ),
          if (_aiLoading)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.35),
                child: const Center(
                  child: Card(
                    elevation: 4,
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: 24, vertical: 20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 12),
                          Text(
                            'AI sedang menganalisis laporan...',
                            style: TextStyle(
                                fontSize: 13, color: AppTheme.textColor),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}