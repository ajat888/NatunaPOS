// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/theme.dart';
import 'screens/login_screen.dart';
import 'screens/main_layout.dart';
import 'services/supabase_service.dart';
import 'services/update_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Bebas portrait & landscape (Opsi B).
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  await SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.manual,
    overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom],
  );

  const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  await SupabaseService().initSession();

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    // Cek update otomatis SEKALI setelah frame pertama tampil,
    // agar Navigator siap. Tidak memblokir startup.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      UpdateService.instance.checkAndNotify();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = SupabaseService().isLoggedIn;

    return MaterialApp(
      navigatorKey: UpdateService.navigatorKey,
      title: 'NatunaPOS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: isLoggedIn ? const MainLayout() : const LoginScreen(),
    );
  }
}