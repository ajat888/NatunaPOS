import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Penting untuk SystemChrome
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/theme.dart';
import 'core/landscape_wrapper.dart'; // Import wrapper baru
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'services/supabase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 1. KUNCI ORIENTASI ANDROID KE LANDSCAPE
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  // Sembunyikan status bar agar lebih maksimal (Opsional)
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  
  const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = SupabaseService().isLoggedIn;

    // 2. BUNGKUS DENGAN LANDSCAPE WRAPPER UNTUK WEB
    return LandscapeWrapper(
      child: MaterialApp(
        title: 'NatunaPOS',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: isLoggedIn ? const HomeScreen() : const LoginScreen(),
      ),
    );
  }
}