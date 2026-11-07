// lib/screens/reports_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/breakpoints.dart';
import '../core/theme.dart';
import '../models/expense.dart';
import '../models/transaction.dart';
import '../services/report_service.dart';

part 'reports/reports_filter_card.dart';
part 'reports/reports_summary_cards.dart';
part 'reports/reports_lists.dart';

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

  static DateTime _todayStart() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  @override
  void initState() {
    super.initState();
    _load();
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
    _load();
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
    _load();
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
    _load();
  }

  @override
  Widget build(BuildContext context) {
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
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Muat ulang',
            onPressed: _load,
          ),
        ],
      ),
      body: RefreshIndicator(
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
                const SizedBox(height: 16),
                _ReportsLists(summary: _summary!),
              ],
            ],
          ),
        ),
      ),
    );
  }
}