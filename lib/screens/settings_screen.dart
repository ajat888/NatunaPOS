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
import '../services/supabase_service.dart';
import '../services/sync_status_service.dart';
import '../services/update_service.dart';
import '../services/printer_service.dart';
import '../widgets/common/main_menu_scope.dart';

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