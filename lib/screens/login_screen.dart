// lib/screens/login_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart'; // ← IMPORT BARU
import '../services/supabase_service.dart';
import '../core/theme.dart';
import '../core/breakpoints.dart';
import 'main_layout.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordFocusNode = FocusNode(); // ← FOKUS BARU
  final _service = SupabaseService();

  static const String _kLastEmailKey = 'natunapos_last_email'; // ← KEY BARU

  bool _isLoading = false;
  String? _errorMessage;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _loadSavedEmail(); // ← PANGGIL FUNGSI SAAT DIBUKA
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordFocusNode.dispose(); // ← DISPOSE FOCUS NODE
    super.dispose();
  }

  // ← FUNGSI BARU UNTUK MEMBACA EMAIL
  Future<void> _loadSavedEmail() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedEmail = prefs.getString(_kLastEmailKey);
      if (savedEmail != null && savedEmail.isNotEmpty && mounted) {
        setState(() {
          _emailController.text = savedEmail;
        });
        // Pindahkan kursor langsung ke password agar user tinggal ketik
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _passwordFocusNode.requestFocus();
        });
      }
    } catch (e) {
      debugPrint('Gagal memuat email tersimpan: $e');
    }
  }

  // ← FUNGSI BARU UNTUK MENYIMPAN EMAIL
  Future<void> _saveEmail(String email) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kLastEmailKey, email);
    } catch (e) {
      debugPrint('Gagal menyimpan email: $e');
    }
  }

  Future<void> _handleLogin() async {
    if (_emailController.text.trim().isEmpty || _passwordController.text.isEmpty) {
      setState(() => _errorMessage = 'Email dan Password tidak boleh kosong');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final email = _emailController.text.trim();
      final mode = await _service.login(
        email,
        _passwordController.text.trim(),
      );
      
      // ← SIMPAN EMAIL SETELAH BERHASIL LOGIN
      await _saveEmail(email); 

      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainLayout()),
      );
      if (mode == LoginMode.offline) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
                'Login offline berhasil. Data akan disinkronkan saat online.'),
            backgroundColor: AppTheme.primaryColor,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Terjadi kesalahan sistem');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = Breakpoints.of(context);
    final isWideScreen = !size.isCompact;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: isWideScreen
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(child: _buildBranding()),
                        const SizedBox(width: 64),
                        Expanded(child: _buildForm()),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildBranding(),
                        const SizedBox(height: 48),
                        _buildForm(),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBranding() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.account_balance_wallet_outlined,
          size: 80,
          color: AppTheme.primaryColor,
        ),
        const SizedBox(height: 32),
        const Text(
          'Selamat Datang',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: AppTheme.textColor,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Silakan masuk untuk mengakses NatunaPOS',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, color: AppTheme.textLightColor),
        ),
      ],
    );
  }

  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_errorMessage != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.dangerColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _errorMessage!,
              style: const TextStyle(color: AppTheme.dangerColor),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
        ],
        TextField(
  controller: _emailController,
  keyboardType: TextInputType.emailAddress,
  textInputAction: TextInputAction.next,
  onSubmitted: (_) => _passwordFocusNode.requestFocus(),
  decoration: const InputDecoration(
    labelText: 'Email',
    prefixIcon: Icon(Icons.email_outlined),
  ),
),
const SizedBox(height: 16),
TextField(
  controller: _passwordController,
  focusNode: _passwordFocusNode,
  obscureText: _obscurePassword,
  textInputAction: TextInputAction.done,
  onSubmitted: (_) => _handleLogin(),
  decoration: InputDecoration(
    labelText: 'Kata Sandi',
    prefixIcon: const Icon(Icons.lock_outline),
    suffixIcon: IconButton(
      icon: Icon(
        _obscurePassword
            ? Icons.visibility_off_outlined
            : Icons.visibility_outlined,
        color: AppTheme.textLightColor,
      ),
      onPressed: () {
        setState(() {
          _obscurePassword = !_obscurePassword;
        });
      },
    ),
  ),
),
        const SizedBox(height: 32),
        ElevatedButton(
  onPressed: _isLoading ? null : _handleLogin,
  child: _isLoading
      ? const SizedBox(
          height: 20,
          width: 20,
          child: CircularProgressIndicator(
              color: Colors.white, strokeWidth: 2)) // <--- Tambahkan 'const' sebelum CircularProgressIndicator
      : const Text('MASUK'),
),
      ],
    );
  }
}