// lib/screens/closing_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/theme.dart';
import '../core/local_db.dart';
import '../models/daily_closing.dart';
import '../services/app_settings.dart';
import '../services/report_service.dart';
import '../services/supabase_service.dart';
import '../services/auto_sync_scheduler.dart';
import '../services/sync_status_service.dart';
import '../widgets/common/thousand_formatter.dart';
import 'login_screen.dart';
import 'reports_screen.dart';

part 'closing/already_closed_view.dart';
part 'closing/closing_summary_section.dart';
part 'closing/closing_cash_section.dart';
part 'closing/closing_confirmation_dialog.dart';

class ClosingScreen extends StatefulWidget {
  const ClosingScreen({super.key});

  @override
  State<ClosingScreen> createState() => _ClosingScreenState();
}

class _ClosingScreenState extends State<ClosingScreen> {
  final _formatter = NumberFormat.decimalPattern('id');
  final _cashController = TextEditingController();
  final _noteController = TextEditingController();
  bool _logoutAfter = true;
  bool _isSaving = false;
  bool _isLoading = true;
  DailyClosing? _existingClosing;
  ReportSummary? _todaySummary;
  int _pendingSync = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _cashController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  String _todayKey() => DateFormat('yyyy-MM-dd').format(DateTime.now());

  int get _cashActual {
    final clean = _cashController.text.replaceAll('.', '').trim();
    return int.tryParse(clean) ?? 0;
  }

  int get _cashDifference =>
      _todaySummary == null ? 0 : _cashActual - _todaySummary!.cashExpected;

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _isSaving = false;
      });
    }
    try {
      final existing = await LocalDb.instance.getDailyClosingByDate(_todayKey());
      if (existing != null) {
        if (!mounted) return;
        setState(() {
          _existingClosing = existing;
          _isLoading = false;
        });
        return;
      }
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final summary = await ReportService.instance.buildReport(
        from: todayStart,
        to: todayStart,
      );
      await SyncStatusService.instance.refreshPendingCount();
      final pending = SyncStatusService.instance.pendingCount.value;
      if (!mounted) return;
      _cashController.text = _formatter.format(summary.cashExpected);
      setState(() {
        _todaySummary = summary;
        _pendingSync = pending;
        _existingClosing = null;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gagal memuat data closing'),
          backgroundColor: AppTheme.dangerColor,
        ),
      );
    }
  }

  Future<void> _submit() async {
  if (_isSaving) return;
  final summary = _todaySummary;
  if (summary == null) return;

  final confirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _ClosingConfirmationDialog(
      totalSales: summary.totalSales,
      cashActual: _cashActual,
      cashDifference: _cashDifference,
    ),
  );
  if (confirmed != true) return;
  if (!mounted) return;

  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context);
  setState(() => _isSaving = true);

  try {
    final cashier = AppSettings.instance.cashierName.value.trim();
    final closedBy = cashier.isEmpty ? 'Kasir' : cashier;
    final closing = DailyClosing(
      id: 0,
      closingDate: _todayKey(),
      totalSales: summary.totalSales,
      totalTransactions: summary.totalTransactions,
      totalHpp: summary.totalHpp,
      totalExpenses: summary.totalExpenses,
      totalVoidAmount:
          summary.totalVoidAmount + summary.totalVoidOpenOrderAmount,
      voidCount: summary.totalVoidCount,
      cashExpected: summary.cashExpected,
      cashActual: _cashActual,
      cashDifference: _cashDifference,
      closingNote: _noteController.text.trim().isEmpty
          ? null
          : _noteController.text.trim(),
      closedBy: closedBy,
      closedAt: DateTime.now(),
    );

    await LocalDb.instance.insertDailyClosing(closing);
AutoSyncScheduler.instance
    .scheduleSync(delay: const Duration(seconds: 1));

if (_logoutAfter) {
      try {
        await SupabaseService().logout();
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Closing berhasil disimpan. Anda telah logout.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
        navigator.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      } on PendingSyncException catch (e) {
        if (!mounted) return;
        setState(() => _isSaving = false);
        final forceLogout = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded,
                    color: AppTheme.dangerColor),
                SizedBox(width: 8),
                Expanded(child: Text('Data Belum Tersinkron')),
              ],
            ),
            content: Text(
              'Ada ${e.pendingCount} perubahan yang belum terkirim ke server.\n\n'
              'Logout paksa akan MENGHILANGKAN data tersebut dari HP ini, '
              'termasuk catatan closing hari ini.\n\n'
              'Saran: sambungkan internet, tunggu sinkronisasi, lalu logout.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('BATAL'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.dangerColor,
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('LOGOUT PAKSA'),
              ),
            ],
          ),
        );
        if (forceLogout != true) {
          await _load();
          return;
        }
        if (!mounted) return;
        setState(() => _isSaving = true);
        try {
          await SupabaseService().logout(force: true);
          messenger.showSnackBar(
            const SnackBar(
              content: Text(
                  'Logout paksa berhasil. Sebagian data mungkin belum terkirim.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 4),
            ),
          );
          navigator.pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
          );
        } catch (err) {
          debugPrint('Forced logout failed: $err');
          AutoSyncScheduler.instance.start();
          if (!mounted) return;
          setState(() => _isSaving = false);
          messenger.showSnackBar(
            SnackBar(
              content: Text(
                  'Gagal logout: ${err.toString().replaceAll('Exception: ', '')}'),
              backgroundColor: AppTheme.dangerColor,
            ),
          );
        }
      }
    } else {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Closing berhasil disimpan.'),
          backgroundColor: Colors.green,
        ),
      );
      await _load();
    }
  } catch (e) {
    if (!mounted) return;
    setState(() => _isSaving = false);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
            'Gagal menyimpan closing: ${e.toString().replaceAll('Exception: ', '')}'),
        backgroundColor: AppTheme.dangerColor,
      ),
    );
  }
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
        title: const Text('Closing Harian'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Muat ulang',
            onPressed: _load,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : (_existingClosing != null
              ? _AlreadyClosedView(
                  closing: _existingClosing!,
                  formatter: _formatter,
                )
              : _buildForm()),
    );
  }

  Widget _buildForm() {
    final summary = _todaySummary;
    if (summary == null) {
      return const Center(
        child: Text('Data hari ini tidak tersedia.',
            style: TextStyle(color: AppTheme.textLightColor)),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ClosingSummarySection(summary: summary, pendingSync: _pendingSync),
          const SizedBox(height: 16),
          _ClosingCashSection(
            cashController: _cashController,
            noteController: _noteController,
            cashExpected: summary.cashExpected,
            cashDifference: _cashDifference,
            logoutAfter: _logoutAfter,
            onLogoutChanged: (v) => setState(() => _logoutAfter = v),
            onCashChanged: () => setState(() {}),
            onSubmit: _submit,
            isSaving: _isSaving,
          ),
        ],
      ),
    );
  }
}