part of '../settings_screen.dart';

class _PrinterSection extends StatefulWidget {
  const _PrinterSection();

  @override
  State<_PrinterSection> createState() => _PrinterSectionState();
}

class _PrinterSectionState extends State<_PrinterSection> {
  bool _scanning = false;
  bool _testing = false;
  List<BluetoothInfo> _devices = [];
  String? _error;

  Future<void> _pickLogo() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 400,
        maxHeight: 400,
        imageQuality: 80,
      );
      
      if (picked != null) {
        final appDir = await getApplicationDocumentsDirectory();
        final fileName = 'logo_${DateTime.now().millisecondsSinceEpoch}.png';
        final localFile = await File(picked.path).copy('${appDir.path}/$fileName');
        await AppSettings.instance.saveLogoPath(localFile.path);
        if (mounted) setState(() {});
      }
    } catch (e) {
      debugPrint('Pick logo failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gagal memuat gambar. Pastikan izin galeri aktif.'),
          backgroundColor: AppTheme.dangerColor,
        ),
      );
    }
  }

  Future<void> _scanDevices() async {
    setState(() { _scanning = true; _error = null; });
    try {
      final devices = await PrinterService.instance.getBondedDevices();
      if (mounted) setState(() => _devices = devices);
    } catch (e) {
      if (mounted) setState(() => _error = 'Gagal scan printer: $e');
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<void> _selectDevice(BluetoothInfo device) async {
    final success = await PrinterService.instance.connect(device.macAdress);
    if (success) {
      await AppSettings.instance.savePrinter(device.macAdress, device.name);
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Printer terhubung'), backgroundColor: Colors.green),
      );
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal terhubung ke printer'), backgroundColor: AppTheme.dangerColor),
      );
    }
  }

  Future<void> _testPrint() async {
    if (AppSettings.instance.printerMac.value == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih printer terlebih dahulu')),
      );
      return;
    }
    setState(() => _testing = true);
    final ok = await PrinterService.instance.printTest();
    if (!mounted) return;
    setState(() => _testing = false);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal mencetak struk test'), backgroundColor: AppTheme.dangerColor),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = AppSettings.instance;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionHeader('Printer & Struk'),
        _card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.image, color: AppTheme.primaryColor),
                title: const Text('Logo Struk'),
                subtitle: Text(settings.logoPath.value != null ? 'Logo terpasang' : 'Belum ada logo'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _pickLogo,
              ),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              ListTile(
                leading: const Icon(Icons.bluetooth, color: AppTheme.primaryColor),
                title: const Text('Printer Bluetooth'),
                subtitle: Text(settings.printerName.value ?? 'Belum terhubung'),
                trailing: _scanning 
                  ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.search),
                onTap: _scanning ? null : _scanDevices,
              ),
              if (_devices.isNotEmpty) ...[
                Container(
                  color: AppTheme.backgroundColor,
                  child: Column(
                    children: _devices.map((d) => ListTile(
                      dense: true,
                      title: Text(d.name),
                      subtitle: Text(d.macAdress),
                      trailing: settings.printerMac.value == d.macAdress 
                        ? const Icon(Icons.check_circle, color: Colors.green, size: 16) 
                        : null,
                      onTap: () => _selectDevice(d),
                    )).toList(),
                  ),
                ),
              ],
              if (_error != null) Padding(
                padding: const EdgeInsets.all(12),
                child: Text(_error!, style: const TextStyle(color: AppTheme.dangerColor, fontSize: 12)),
              ),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              ListTile(
                leading: const Icon(Icons.print, color: AppTheme.primaryColor),
                title: const Text('Test Print'),
                trailing: _testing 
                  ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.chevron_right),
                onTap: _testing ? null : _testPrint,
              ),
            ],
          ),
        ),
      ],
    );
  }
}