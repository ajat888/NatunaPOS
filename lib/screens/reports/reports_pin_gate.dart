part of '../reports_screen.dart';

class _PinGateDialog extends StatefulWidget {
  final bool isSetup;
  final Future<PinVerifyResult> Function(String pin) onVerify;
  final Future<void> Function(String pin) onSetup;
  final Future<void> Function({
    required String email,
    required String password,
  }) onReset;

  const _PinGateDialog({
    required this.isSetup,
    required this.onVerify,
    required this.onSetup,
    required this.onReset,
  });

  @override
  State<_PinGateDialog> createState() => _PinGateDialogState();
}

class _PinGateDialogState extends State<_PinGateDialog> {
  final _pinController = TextEditingController();
  final _confirmController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmFocusNode = FocusNode();
  bool _busy = false;
  String? _error;
  int _lockedUntilMs = 0;
  bool _showReset = false;
  bool _forcedSetup = false;

  bool get _effectiveSetup => widget.isSetup || _forcedSetup;

  @override
  void dispose() {
    _pinController.dispose();
    _confirmController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmFocusNode.dispose();
    super.dispose();
  }

  bool _isLocked() =>
      _lockedUntilMs > 0 &&
      DateTime.now().millisecondsSinceEpoch < _lockedUntilMs;

  String _lockRemaining() {
    final ms = _lockedUntilMs - DateTime.now().millisecondsSinceEpoch;
    if (ms <= 0) return '0';
    final m = (ms / 60000).ceil();
    return '$m';
  }

  Future<void> _submitPin() async {
    if (_busy) return;
    final pin = _pinController.text.trim();
    if (pin.length != 6 || int.tryParse(pin) == null) {
      setState(() => _error = 'PIN harus 6 digit angka');
      return;
    }
    if (_isLocked()) {
      setState(
          () => _error = 'Terkunci. Coba lagi dalam ${_lockRemaining()} menit.');
      return;
    }
    if (_effectiveSetup && _confirmController.text.trim() != pin) {
      setState(() => _error = 'Konfirmasi PIN tidak sama');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_effectiveSetup) {
        await widget.onSetup(pin);
        if (!mounted) return;
        Navigator.pop(context, pin);
        return;
      }
      final result = await widget.onVerify(pin);
      if (!mounted) return;
      if (result.valid) {
        Navigator.pop(context, pin);
        return;
      }
      setState(() {
        _busy = false;
        _lockedUntilMs = result.lockedUntilMs;
        _pinController.clear();
        if (result.lockedUntilMs > 0 &&
            DateTime.now().millisecondsSinceEpoch < result.lockedUntilMs) {
          _error = 'PIN salah. Terkunci ${_lockRemaining()} menit.';
        } else {
          final remaining = 5 - result.failedAttempts;
          _error = 'PIN salah. Sisa percobaan: $remaining';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<void> _submitReset() async {
    if (_busy) return;
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Email dan password wajib diisi');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onReset(email: email, password: password);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _showReset = false;
        _forcedSetup = true;
        _error = null;
        _emailController.clear();
        _passwordController.clear();
        _pinController.clear();
        _confirmController.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PIN direset. Silakan buat PIN baru.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.sizeOf(context).width;
    final contentW = screenW < 528 ? screenW - 88 : 420.0;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || _busy) return;
        Navigator.pop(context);
      },
      child: AlertDialog(
        scrollable: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        title: Row(
          children: [
            Icon(
              _showReset ? Icons.lock_reset : Icons.lock_outline,
              color: AppTheme.primaryColor,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _showReset
                    ? 'Reset PIN'
                    : (_effectiveSetup ? 'Buat PIN Owner' : 'PIN Owner'),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: contentW,
          child: _showReset ? _buildResetForm() : _buildPinForm(),
        ),
        actions: _showReset
            ? [
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => setState(() {
                            _showReset = false;
                            _error = null;
                          }),
                  child: const Text('KEMBALI'),
                ),
                ElevatedButton(
                  onPressed: _busy ? null : _submitReset,
                  child: _busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('RESET'),
                ),
              ]
            : [
                TextButton(
                  onPressed: _busy ? null : () => Navigator.pop(context),
                  child: const Text('BATAL'),
                ),
                ElevatedButton(
                  onPressed: _busy ? null : _submitPin,
                  child: _busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : Text(_effectiveSetup ? 'SIMPAN' : 'BUKA'),
                ),
              ],
      ),
    );
  }

  Widget _buildPinForm() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _effectiveSetup
              ? 'Buat PIN 6 digit untuk melindungi halaman Laporan dari akses kasir.'
              : 'Masukkan PIN owner untuk membuka halaman Laporan.',
          style: const TextStyle(fontSize: 13, color: AppTheme.textColor),
        ),
        const SizedBox(height: 12),
        if (_error != null) ...[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.dangerColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _error!,
              style: const TextStyle(
                  color: AppTheme.dangerColor, fontSize: 12),
            ),
          ),
          const SizedBox(height: 12),
        ],
        TextField(
          controller: _pinController,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          obscureText: true,
          maxLength: 6,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'PIN (6 digit)',
            counterText: '',
          ),
          onSubmitted: (_) => _submitPin(),
          onChanged: (val) {
            if (val.length == 6) {
              if (!_effectiveSetup) {
                _submitPin();
              } else {
                _confirmFocusNode.requestFocus();
              }
            }
          },
        ),
        if (_effectiveSetup) ...[
          const SizedBox(height: 8),
          TextField(
            controller: _confirmController,
            focusNode: _confirmFocusNode,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            obscureText: true,
            maxLength: 6,
            decoration: const InputDecoration(
              labelText: 'Konfirmasi PIN',
              counterText: '',
            ),
            onSubmitted: (_) => _submitPin(),
            onChanged: (val) {
              if (val.length == 6) {
                _submitPin();
              }
            },
          ),
        ],
        if (!_effectiveSetup)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: _busy
                  ? null
                  : () => setState(() {
                        _showReset = true;
                        _error = null;
                      }),
              child: const Text('Lupa PIN?'),
            ),
          ),
      ],
    );
  }

  Widget _buildResetForm() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Reset PIN memerlukan email dan password akun Anda.',
          style: TextStyle(fontSize: 13, color: AppTheme.textColor),
        ),
        const SizedBox(height: 12),
        if (_error != null) ...[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.dangerColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _error!,
              style: const TextStyle(
                  color: AppTheme.dangerColor, fontSize: 12),
            ),
          ),
          const SizedBox(height: 12),
        ],
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'Email'),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _passwordController,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Password'),
        ),
      ],
    );
  }
}