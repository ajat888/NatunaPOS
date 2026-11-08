part of '../kelola_screen.dart';

class _ProductDialog extends StatefulWidget {
  final Product? existing;
  final List<Category> categories;
  final SupabaseService service;
  const _ProductDialog(
      {this.existing, required this.categories, required this.service});
  @override
  State<_ProductDialog> createState() => _ProductDialogState();
}

class _ProductDialogState extends State<_ProductDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _priceController;
  late final TextEditingController _hppController;
  int? _selectedCategoryId;
  String? _existingImageUrl;
  String? _localImagePath;
  bool _isSaving = false;
  bool _isPickingImage = false;
  String? _errorMessage;

  Timer? _debounce;
  String? _nameError;

  @override
  void initState() {
    super.initState();
    _nameController =
        TextEditingController(text: widget.existing?.name ?? '');
    final formatCurrency = NumberFormat.decimalPattern('id');
    _priceController = TextEditingController(
        text: widget.existing != null
            ? formatCurrency.format(widget.existing!.price)
            : '');
    _hppController = TextEditingController(
        text: widget.existing != null
            ? formatCurrency.format(widget.existing!.hpp)
            : '');
    _selectedCategoryId = widget.existing?.categoryId;
    if (_selectedCategoryId != null &&
        !widget.categories.any((c) => c.id == _selectedCategoryId)) {
      _selectedCategoryId = null;
    }
    _existingImageUrl = widget.existing?.imageUrl;
    _localImagePath = widget.existing?.localImagePath;
    if (_localImagePath != null && !File(_localImagePath!).existsSync()) {
      _localImagePath = null;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _hppController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _checkDuplicateName(String name) async {
    if (name.trim().isEmpty) {
      if (mounted) setState(() => _nameError = null);
      return;
    }
    final isDup = await widget.service.isProductNameDuplicate(
      name,
      excludeId: widget.existing?.id,
    );
    if (mounted) {
      setState(() => _nameError = isDup ? 'Nama produk sudah ada' : null);
    }
  }

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
    if (_isPickingImage) return;
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (ctx) => SimpleDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        title: const Text('Pilih Sumber Foto'),
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
    await _pickImage(source);
  }

  Future<void> _pickImage(ImageSource source) async {
    if (_isPickingImage) return;

    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();

    setState(() => _isPickingImage = true);
    await _writePickerMarker(true);

    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        imageQuality: 40,
        maxWidth: 500,
        maxHeight: 500,
        requestFullMetadata: false,
      );

      await _writePickerMarker(false);

      if (pickedFile == null) {
        if (mounted) setState(() => _isPickingImage = false);
        return;
      }

      final sourceFile = File(pickedFile.path);
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
      final fileName = 'img_${DateTime.now().microsecondsSinceEpoch}.jpg';
      final localFile = await sourceFile.copy('${appDir.path}/$fileName');

      if (!mounted) return;
      setState(() {
        _localImagePath = localFile.path;
        _isPickingImage = false;
      });
    } on PlatformException catch (e) {
      await _writePickerMarker(false);
      debugPrint('Pick image platform error: ${e.code} / ${e.message}');
      if (!mounted) return;
      setState(() => _isPickingImage = false);
      final msg = (e.message ?? '').toLowerCase();
      final isPermission = msg.contains('permission') ||
          msg.contains('denied') ||
          msg.contains('access') ||
          e.code == 'photo_access_denied' ||
          e.code == 'camera_access_denied';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(isPermission
            ? 'Izin ditolak. Buka Setelan HP → Aplikasi → NatunaPOS → Izin → Foto/Video/Kamera → Izinkan.'
            : 'Gagal membuka ${source == ImageSource.camera ? "kamera" : "galeri"}.\nKode: ${e.code}\n${e.message ?? ""}'),
        backgroundColor: AppTheme.dangerColor,
        duration: const Duration(seconds: 8),
      ));
    } catch (e) {
      await _writePickerMarker(false);
      debugPrint('Pick image failed: $e');
      if (!mounted) return;
      setState(() => _isPickingImage = false);
      final msg = e.toString().replaceAll('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Gagal memilih gambar: $msg'),
        backgroundColor: AppTheme.dangerColor,
        duration: const Duration(seconds: 6),
      ));
    }
  }

  Future<void> _save() async {
    if (_nameError != null) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final name = _nameController.text.trim();
      final price =
          int.parse(_priceController.text.replaceAll('.', '').trim());
      final hpp = int.parse(_hppController.text.replaceAll('.', '').trim());

      if (widget.existing == null) {
        await widget.service.createProduct(
            name: name,
            price: price,
            hpp: hpp,
            categoryId: _selectedCategoryId,
            localImagePath: _localImagePath);
      } else {
        await widget.service.updateProduct(
            id: widget.existing!.id,
            name: name,
            price: price,
            hpp: hpp,
            categoryId: _selectedCategoryId,
            localImagePath: _localImagePath,
            existingImageUrl: _existingImageUrl);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    ImageProvider? imageProvider;
    if (_localImagePath != null && File(_localImagePath!).existsSync()) {
      imageProvider = FileImage(File(_localImagePath!));
    } else if (_existingImageUrl != null && _existingImageUrl!.isNotEmpty) {
      imageProvider = NetworkImage(_existingImageUrl!);
    }

    return AlertDialog(
      scrollable: true,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      title: Text(widget.existing == null ? 'Tambah Produk' : 'Edit Produk'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_errorMessage != null) ...[
                Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        color: AppTheme.dangerColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8)),
                    child: Text(_errorMessage!,
                        style: const TextStyle(
                            color: AppTheme.dangerColor, fontSize: 12))),
                const SizedBox(height: 12),
              ],
              Center(
                child: GestureDetector(
                  onTap: _isPickingImage ? null : _showSourcePicker,
                  child: Container(
                    height: 120,
                    width: 120,
                    decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        image: imageProvider != null
                            ? DecorationImage(
                                image: imageProvider, fit: BoxFit.cover)
                            : null),
                    child: _isPickingImage
                        ? const Center(
                            child: SizedBox(
                                height: 24,
                                width: 24,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2)))
                        : imageProvider == null
                            ? const Icon(Icons.add_a_photo_outlined,
                                color: AppTheme.textLightColor, size: 32)
                            : null,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                  controller: _nameController,
                  inputFormatters: [TitleCaseFormatter()],
                  decoration: InputDecoration(
                    labelText: 'Nama Produk',
                    errorText: _nameError,
                  ),
                  onChanged: (val) {
                    if (_debounce?.isActive ?? false) _debounce!.cancel();
                    _debounce = Timer(const Duration(milliseconds: 400), () {
                      _checkDuplicateName(val);
                    });
                  },
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Nama wajib diisi'
                      : null),
              const SizedBox(height: 12),
              TextFormField(
                  controller: _hppController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [ThousandFormatter()],
                  decoration: const InputDecoration(
                      labelText: 'HPP (Harga Modal)', prefixText: 'Rp '),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'HPP wajib diisi';
                    final n = int.tryParse(v.trim().replaceAll('.', ''));
                    if (n == null || n < 0) return 'HPP tidak valid';
                    return null;
                  }),
              const SizedBox(height: 12),
              TextFormField(
                  controller: _priceController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [ThousandFormatter()],
                  decoration: const InputDecoration(
                      labelText: 'Harga Jual', prefixText: 'Rp '),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Harga jual wajib diisi';
                    }
                    final n = int.tryParse(v.trim().replaceAll('.', ''));
                    if (n == null || n < 0) return 'Harga tidak valid';
                    return null;
                  }),
              const SizedBox(height: 12),
              DropdownButtonFormField<int?>(
                value: _selectedCategoryId,
                decoration:
                    const InputDecoration(labelText: 'Kategori (opsional)'),
                items: [
                  const DropdownMenuItem<int?>(
                      value: null, child: Text('Tanpa Kategori')),
                  ...widget.categories.map((c) =>
                      DropdownMenuItem<int?>(value: c.id, child: Text(c.name)))
                ],
                onChanged: (v) => setState(() => _selectedCategoryId = v),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: _isSaving ? null : () => Navigator.pop(context, false),
            child: const Text('BATAL')),
        ElevatedButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Text('SIMPAN')),
      ],
    );
  }
}