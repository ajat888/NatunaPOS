import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/theme.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'services/supabase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
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

    return MaterialApp(
      title: 'NatunaPOS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      // Routing otomatis: Jika sudah login langsung ke Home, jika belum ke Login
      home: isLoggedIn ? const HomeScreen() : const LoginScreen(),
    );
  }
}