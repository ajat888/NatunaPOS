part of '../kelola_screen.dart';

class _ThousandFormatter extends TextInputFormatter {
  final NumberFormat _formatter = NumberFormat.decimalPattern('id');
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue;
    String cleanText = newValue.text.replaceAll('.', '');
    if (cleanText.isEmpty) return newValue.copyWith(text: '');
    final int? value = int.tryParse(cleanText);
    if (value == null) return oldValue;
    final String formatted = _formatter.format(value);
    return TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length));
  }
}

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
  File? _imageFile;
  String? _existingImageUrl;
  String? _localImagePath;
  bool _isSaving = false;
  String? _errorMessage;

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
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _hppController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
          source: ImageSource.gallery, imageQuality: 70);
      if (pickedFile != null) {
        final appDir = await getApplicationDocumentsDirectory();
        final fileName = 'img_${DateTime.now().microsecondsSinceEpoch}.jpg';
        final localFile =
            await File(pickedFile.path).copy('${appDir.path}/$fileName');
        setState(() {
          _imageFile = localFile;
          _localImagePath = localFile.path;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Gagal memilih gambar: $e'),
          backgroundColor: AppTheme.dangerColor));
    }
  }

  Future<void> _save() async {
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
                  onTap: _pickImage,
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
                    child: imageProvider == null
                        ? const Icon(Icons.add_a_photo_outlined,
                            color: AppTheme.textLightColor, size: 32)
                        : null,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Nama Produk'),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Nama wajib diisi'
                      : null),
              const SizedBox(height: 12),
              TextFormField(
                  controller: _hppController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [_ThousandFormatter()],
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
                  inputFormatters: [_ThousandFormatter()],
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