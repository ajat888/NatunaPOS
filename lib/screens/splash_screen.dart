import 'package:flutter/material.dart';
import '../core/theme.dart';

class SplashScreen extends StatefulWidget {
  final Widget Function() onFinished;
  const SplashScreen({super.key, required this.onFinished});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeLogo;
  late final Animation<double> _scaleLogo;
  late final Animation<double> _fadeTitle;
  late final Animation<double> _fadeTagline;
  late final Animation<double> _fadeCredit;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeLogo = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.30, curve: Curves.easeOut),
    );
    _scaleLogo = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.30, curve: Curves.easeOutCubic),
      ),
    );
    _fadeTitle = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.067, 0.333, curve: Curves.easeOut),
    );
    _fadeTagline = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.133, 0.367, curve: Curves.easeOut),
    );
    _fadeCredit = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.233, 0.433, curve: Curves.easeOut),
    );

    _controller.addStatusListener(_onStatus);
    _controller.forward();
  }

  void _onStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (_, __, ___) => widget.onFinished(),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  void dispose() {
    _controller.removeStatusListener(_onStatus);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryColor,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ScaleTransition(
                scale: _scaleLogo,
                child: FadeTransition(
                  opacity: _fadeLogo,
                  child: const Icon(
                    Icons.account_balance_wallet_outlined,
                    size: 88,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              FadeTransition(
                opacity: _fadeTitle,
                child: const Text(
                  'NatunaPOS',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              FadeTransition(
                opacity: _fadeTagline,
                child: Text(
                  'Smart POS & Business Analytics',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.75),
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              const SizedBox(height: 56),
              FadeTransition(
                opacity: _fadeCredit,
                child: Text(
                  'Made by Ajat Sanjaya',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withOpacity(0.55),
                    fontStyle: FontStyle.italic,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}