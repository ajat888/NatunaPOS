part of '../settings_screen.dart';

class _PrinterSection extends StatefulWidget {
  const _PrinterSection();

  @override
  State<_PrinterSection> createState() => _PrinterSectionState();
}

class _PrinterSectionState extends State<_PrinterSection> {
  bool _scanning = false;
  bool _testing = false;
  bool _pickingLogo = false;
  List<BluetoothInfo> _devices = [];
  String? _error;

  Future<void> _writePickerMarker(bool active) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      if (!await dir.exists()) {
        if (active) await dir.create(recursive: true);
      }
      final marker = File('${dir.path}/.picker_in_progress');
      if (active) {
        await marker.writeAsString('1', flush: true);
      } else if (await marker.exists()) {
        await marker.delete();
      }
    } catch (e) {
      debugPrint('Picker marker write failed: $e');
    }
  }

  Future<void> _showSourcePicker() async {
    if (_pickingLogo) return;
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (ctx) => SimpleDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        title: const Text('Pilih Sumber Logo'),
        children: [
          SimpleDialogOption(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            onPressed: () => Navigator.pop(ctx, ImageSource.gallery),
            child: const Row(
              children: [
                Icon(Icons.photo_library_outlined,
                    color: AppTheme.primaryColor),
                SizedBox(width: 12),
                Text('Pilih dari Galeri'),
              ],
            ),
          ),
          SimpleDialogOption(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            onPressed: () => Navigator.pop(ctx, ImageSource.camera),
            child: const Row(
              children: [
                Icon(Icons.photo_camera_outlined,
                    color: AppTheme.primaryColor),
                SizedBox(width: 12),
                Text('Ambil Foto (Kamera)'),
              ],
            ),
          ),
        ],
      ),
    );
    if (source == null || !mounted) return;
    await _pickLogo(source);
  }

  Future<void> _pickLogo(ImageSource source) async {
    if (_pickingLogo) return;

    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();

    setState(() => _pickingLogo = true);
    await _writePickerMarker(true);

    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 400,
        maxHeight: 400,
        imageQuality: 50,
        requestFullMetadata: false,
      );

      await _writePickerMarker(false);

      if (picked == null) {
        if (mounted) setState(() => _pickingLogo = false);
        return;
      }

      final sourceFile = File(picked.path);
      if (!await sourceFile.exists()) {
        throw Exception('File gambar tidak ditemukan');
      }

      final fileSize = await sourceFile.length();
      if (fileSize > 3 * 1024 * 1024) {
        throw Exception(
            'Ukuran gambar terlalu besar (>3MB). Pilih yang lebih kecil.');
      }

      final appDir = await getApplicationDocumentsDirectory();
      if (!await appDir.exists()) {
        await appDir.create(recursive: true);
      }
      final fileName = 'logo_${DateTime.now().millisecondsSinceEpoch}.png';
      final localFile = await sourceFile.copy('${appDir.path}/$fileName');
      await AppSettings.instance.saveLogoPath(localFile.path);

      if (!mounted) return;
      setState(() => _pickingLogo = false);
    } on PlatformException catch (e) {
      await _writePickerMarker(false);
      debugPrint('Pick logo platform error: ${e.code} / ${e.message}');
      if (!mounted) return;
      setState(() => _pickingLogo = false);
      final msg = (e.message ?? '').toLowerCase();
      final isPermission = msg.contains('permission') ||
          msg.contains('denied') ||
          msg.contains('access') ||
          e.code == 'photo_access_denied' ||
          e.code == 'camera_access_denied';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isPermission
              ? 'Izin ditolak. Buka Setelan HP → Aplikasi → NatunaPOS → Izin → Foto/Video/Kamera → Izinkan.'
              : 'Gagal membuka ${source == ImageSource.camera ? "kamera" : "galeri"}.\nKode: ${e.code}\n${e.message ?? ""}'),
          backgroundColor: AppTheme.dangerColor,
          duration: const Duration(seconds: 8),
        ),
      );
    } catch (e) {
      await _writePickerMarker(false);
      debugPrint('Pick logo failed: $e');
      if (!mounted) return;
      setState(() => _pickingLogo = false);
      final msg = e.toString().replaceAll('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memuat gambar: $msg'),
          backgroundColor: AppTheme.dangerColor,
          duration: const Duration(seconds: 6),
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

    final logoPath = settings.logoPath.value;
    final hasLogo = logoPath != null && File(logoPath).existsSync();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionHeader('Printer & Struk'),
        _card(
          child: Column(
            children: [
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _pickingLogo
                      ? const Center(
                          child: SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2)))
                      : hasLogo
                          ? Image.file(File(logoPath),
                              fit: BoxFit.contain, cacheWidth: 120)
                          : const Icon(Icons.image, color: AppTheme.primaryColor),
                ),
                title: const Text('Logo Struk'),
                subtitle: Text(hasLogo ? 'Logo terpasang' : 'Belum ada logo'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _pickingLogo ? null : _showSourcePicker,
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