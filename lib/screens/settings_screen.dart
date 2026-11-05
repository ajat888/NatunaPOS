import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../core/theme.dart';
import '../core/tax_settings.dart';
import '../services/app_settings.dart';
import '../services/supabase_service.dart';
import '../services/sync_status_service.dart';
import '../services/update_service.dart';
import '../widgets/common/main_menu_scope.dart';

part 'settings/settings_store_form.dart';
part 'settings/settings_profile_form.dart';
part 'settings/settings_tax_form.dart';
part 'settings/settings_about_section.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
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
        children: const [
          _StoreInfoSection(),
          SizedBox(height: 16),
          _ProfileSection(),
          SizedBox(height: 16),
          _TaxSection(),
          SizedBox(height: 16),
          _AboutSection(),
          SizedBox(height: 24),
        ],
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