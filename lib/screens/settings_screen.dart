// lib/screens/settings_screen.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import '../core/theme.dart';
import '../core/tax_settings.dart';
import '../services/app_settings.dart';
import '../services/auto_sync_scheduler.dart';
import '../services/supabase_service.dart';
import '../services/sync_status_service.dart';
import '../services/update_service.dart';
import '../services/printer_service.dart';
import '../widgets/common/main_menu_scope.dart';
import 'login_screen.dart';

part 'settings/settings_store_form.dart';
part 'settings/settings_profile_form.dart';
part 'settings/settings_tax_form.dart';
part 'settings/settings_printer_form.dart';
part 'settings/settings_about_section.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          tooltip: 'Menu',
          onPressed: () => MainMenuScope.of(context)?.openMenu(),
        ),
        title: const Text('Pengaturan'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SettingsMenuItem(
            icon: Icons.storefront_outlined,
            title: 'Info Toko',
            subtitle: 'Nama toko, alamat, dan footer struk',
            onTap: () => _openSection(
              context,
              'Info Toko',
              const _StoreInfoSection(),
            ),
          ),
          const SizedBox(height: 8),
          _SettingsMenuItem(
            icon: Icons.person_outline,
            title: 'Profil Kasir',
            subtitle: 'Nama kasir yang tampil di aplikasi',
            onTap: () => _openSection(
              context,
              'Profil Kasir',
              const _ProfileSection(),
            ),
          ),
          const SizedBox(height: 8),
          _SettingsMenuItem(
            icon: Icons.print_outlined,
            title: 'Printer & Struk',
            subtitle: 'Koneksi printer bluetooth dan logo struk',
            onTap: () => _openSection(
              context,
              'Printer & Struk',
              const _PrinterSection(),
            ),
          ),
          const SizedBox(height: 8),
          _SettingsMenuItem(
            icon: Icons.receipt_long_outlined,
            title: 'Pajak & Diskon',
            subtitle: 'Pengaturan PPN dan persentase',
            onTap: () => _openSection(
              context,
              'Pajak & Diskon',
              const _TaxSection(),
            ),
          ),
          const SizedBox(height: 8),
          _SettingsMenuItem(
            icon: Icons.info_outline,
            title: 'Tentang Aplikasi',
            subtitle: 'Versi, sinkronisasi, dan pembaruan',
            onTap: () => _openSection(
              context,
              'Tentang Aplikasi',
              const _AboutSection(),
            ),
          ),
          const SizedBox(height: 24),
          const _LogoutSection(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  void _openSection(BuildContext context, String title, Widget child) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _SettingsDetailPage(title: title, child: child),
      ),
    );
  }
}

class _LogoutSection extends StatefulWidget {
  const _LogoutSection();

  @override
  State<_LogoutSection> createState() => _LogoutSectionState();
}

class _LogoutSectionState extends State<_LogoutSection> {
  bool _busy = false;

  Future<void> _handleLogout() async {
    if (_busy) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        title: const Row(
          children: [
            Icon(Icons.logout, color: AppTheme.dangerColor),
            SizedBox(width: 8),
            Expanded(child: Text('Keluar Akun')),
          ],
        ),
        content: const Text(
          'Yakin ingin keluar dari akun ini?\n\n'
          'Anda harus login kembali untuk menggunakan aplikasi.',
          style: TextStyle(fontSize: 13, color: AppTheme.textColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('BATAL'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.dangerColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('KELUAR'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;

    setState(() => _busy = true);

    try {
      await SupabaseService().logout();
    } on PendingSyncException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      final force = await _confirmForceLogout(e.pendingCount);
      if (force != true) return;
      if (!mounted) return;
      setState(() => _busy = true);
      try {
        await SupabaseService().logout(force: true);
      } catch (err) {
        debugPrint('Forced logout failed: $err');
        AutoSyncScheduler.instance.start();
        if (!mounted) return;
        setState(() => _busy = false);
        _showError('Gagal logout. Coba lagi.');
        return;
      }
    } catch (e) {
      debugPrint('Logout failed: $e');
      AutoSyncScheduler.instance.start();
      if (!mounted) return;
      setState(() => _busy = false);
      _showError('Gagal logout. Coba lagi.');
      return;
    }

      if (!mounted) return;
  await Navigator.pushAndRemoveUntil(
    context,
    MaterialPageRoute(builder: (_) => const LoginScreen()),
    (route) => false,
  );
}

  Future<bool?> _confirmForceLogout(int pendingCount) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppTheme.dangerColor),
            SizedBox(width: 8),
            Expanded(child: Text('Data Belum Tersinkron')),
          ],
        ),
        content: Text(
          'Ada $pendingCount perubahan yang belum terkirim ke server '
          '(kemungkinan karena tidak ada internet).\n\n'
          'Jika Anda tetap logout, data tersebut akan hilang permanen '
          'dari HP ini.\n\n'
          'Saran: sambungkan internet, tunggu hingga sinkronisasi selesai, '
          'lalu logout lagi.',
          style: const TextStyle(fontSize: 13, color: AppTheme.textColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('BATAL'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.dangerColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('LOGOUT PAKSA'),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.dangerColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.dangerColor.withOpacity(0.3)),
      ),
      child: ListTile(
        onTap: _busy ? null : _handleLogout,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppTheme.dangerColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: _busy
              ? const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.dangerColor,
                    ),
                  ),
                )
              : const Icon(Icons.logout, color: AppTheme.dangerColor),
        ),
        title: const Text(
          'Keluar Akun',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: AppTheme.dangerColor,
          ),
        ),
        subtitle: const Padding(
          padding: EdgeInsets.only(top: 4),
          child: Text(
            'Logout dan kembali ke halaman login',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textLightColor,
            ),
          ),
        ),
        trailing: const Icon(
          Icons.chevron_right,
          color: AppTheme.textLightColor,
        ),
      ),
    );
  }
}

class _SettingsDetailPage extends StatelessWidget {
  final String title;
  final Widget child;

  const _SettingsDetailPage({required this.title, required this.child});

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
        title: Text(title),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          child,
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _SettingsMenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsMenuItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppTheme.primaryColor),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: AppTheme.textColor,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            subtitle,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textLightColor,
            ),
          ),
        ),
        trailing: const Icon(
          Icons.chevron_right,
          color: AppTheme.textLightColor,
        ),
      ),
    );
  }
}

Widget _sectionHeader(String title) {
  return Padding(
    padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
    child: Text(
      title.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
        color: AppTheme.textLightColor,
      ),
    ),
  );
}

Widget _card({required Widget child}) {
  return Container(
    decoration: BoxDecoration(
      color: AppTheme.surfaceColor,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: const Color(0xFFE2E8F0)),
    ),
    child: child,
  );
}