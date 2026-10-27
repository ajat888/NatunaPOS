import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../core/theme.dart';
import '../models/product.dart';
import '../models/category.dart';
import '../services/supabase_service.dart';

class KelolaScreen extends StatefulWidget {
  const KelolaScreen({super.key});

  @override
  State<KelolaScreen> createState() => _KelolaScreenState();
}

class _KelolaScreenState extends State<KelolaScreen>
    with SingleTickerProviderStateMixin {
  final _service = SupabaseService();
  late final TabController _tabController;

  List<Product> _products = [];
  List<Category> _categories = [];
  int? _filterCategoryId; // null = Semua Kategori
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final products = await _service.fetchProducts();
      final categories = await _service.fetchCategories();
      if (!mounted) return;
      setState(() {
        _products = products;
        _categories = categories;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Gagal memuat data. Periksa koneksi Anda.';
      });
    }
  }

  String? _categoryName(int? id) {
    if (id == null) return null;
    for (final c in _categories) {
      if (c.id == id) return c.name;
    }
    return null;
  }

  List<Product> get _filteredProducts {
    if (_filterCategoryId == null) return _products;
    return _products.where((p) => p.categoryId == _filterCategoryId).toList();
  }

  Future<void> _showProductDialog({Product? existing}) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ProductDialog(
        existing: existing,
        categories: _categories,
        service: _service,
      ),
    );
    if (result == true) await _loadAll();
  }

  Future<void> _showCategoryDialog({Category? existing}) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _CategoryDialog(
        existing: existing,
        service: _service,
      ),
    );
    if (result == true) await _loadAll();
  }

  Future<void> _confirmDeleteProduct(Product product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        title: const Text('Hapus Produk'),
        content: Text('Yakin ingin menghapus "${product.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('BATAL'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.dangerColor),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('HAPUS'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _service.deleteProduct(product.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Produk dihapus'), backgroundColor: Colors.green),
      );
      await _loadAll();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _confirmDeleteCategory(Category category) async {
    final affected = _products.where((p) => p.categoryId == category.id).length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        title: const Text('Hapus Kategori'),
        content: Text(
          'Yakin ingin menghapus kategori "${category.name}"?'
          '${affected > 0 ? '\n\n$affected produk akan menjadi Tanpa Kategori.' : ''}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('BATAL'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.dangerColor),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('HAPUS'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _service.deleteCategory(category.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kategori dihapus'), backgroundColor: Colors.green),
      );
      await _loadAll();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Kelola Data'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAll,
            tooltip: 'Muat ulang',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: AppTheme.textLightColor,
          indicatorColor: AppTheme.primaryColor,
          labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
          tabs: const [
            Tab(text: 'PRODUK'),
            Tab(text: 'KATEGORI'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_errorMessage!, style: const TextStyle(color: AppTheme.dangerColor)),
                      const SizedBox(height: 16),
                      TextButton(onPressed: _loadAll, child: const Text('Coba Lagi')),
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildProductsTab(),
                    _buildCategoriesTab(),
                  ],
                ),
    );
  }

  Widget _buildProductsTab() {
    return Stack(
      children: [
        Column(
          children: [
            // Filter Kategori
            if (_categories.isNotEmpty)
              Container(
                height: 50,
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    ChoiceChip(
                      label: const Text('Semua'),
                      selected: _filterCategoryId == null,
                      onSelected: (val) => setState(() => _filterCategoryId = null),
                    ),
                    const SizedBox(width: 8),
                    ..._categories.map((c) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(c.name),
                        selected: _filterCategoryId == c.id,
                        onSelected: (val) => setState(() => _filterCategoryId = c.id),
                      ),
                    )),
                  ],
                ),
              ),
            // Grid Produk
            Expanded(
              child: _filteredProducts.isEmpty
                  ? const Center(
                      child: Text(
                        'Tidak ada produk di kategori ini.',
                        style: TextStyle(color: AppTheme.textLightColor),
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 220,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.75, // Proporsi kotak
                      ),
                      itemCount: _filteredProducts.length,
                      itemBuilder: (context, index) {
                        final product = _filteredProducts[index];
                        return Container(
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceColor,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Gambar
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                                  child: product.imageUrl != null && product.imageUrl!.isNotEmpty
                                      ? Image.network(
                                          product.imageUrl!,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => _buildImagePlaceholder(),
                                        )
                                      : _buildImagePlaceholder(),
                                ),
                              ),
                              // Detail
                              Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      product.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.textColor,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Rp ${NumberFormat.decimalPattern('id').format(product.price)}',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: AppTheme.primaryColor,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        InkWell(
                                          onTap: () => _showProductDialog(existing: product),
                                          child: const Icon(Icons.edit_outlined, color: AppTheme.primaryColor, size: 20),
                                        ),
                                        const SizedBox(width: 12),
                                        InkWell(
                                          onTap: () => _confirmDeleteProduct(product),
                                          child: const Icon(Icons.delete_outline, color: AppTheme.dangerColor, size: 20),
                                        ),
                                      ],
                                    )
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton.extended(
            backgroundColor: AppTheme.primaryColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            onPressed: () => _showProductDialog(),
            icon: const Icon(Icons.add),
            label: const Text('Tambah Produk'),
          ),
        ),
      ],
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      color: const Color(0xFFF1F5F9),
      child: const Center(
        child: Icon(Icons.image_outlined, color: AppTheme.textLightColor, size: 40),
      ),
    );
  }

  Widget _buildCategoriesTab() {
    return Stack(
      children: [
        _categories.isEmpty
            ? const Center(
                child: Text(
                  'Belum ada kategori. Tambahkan kategori pertama Anda.',
                  style: TextStyle(color: AppTheme.textLightColor),
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                itemCount: _categories.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final category = _categories[index];
                  final count = _products.where((p) => p.categoryId == category.id).length;
                  return Container(
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      title: Text(
                        category.name,
                        style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textColor),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '$count produk',
                          style: const TextStyle(color: AppTheme.textLightColor, fontSize: 13),
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, color: AppTheme.primaryColor),
                            onPressed: () => _showCategoryDialog(existing: category),
                            tooltip: 'Edit',
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: AppTheme.dangerColor),
                            onPressed: () => _confirmDeleteCategory(category),
                            tooltip: 'Hapus',
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton.extended(
            backgroundColor: AppTheme.primaryColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            onPressed: () => _showCategoryDialog(),
            icon: const Icon(Icons.add),
            label: const Text('Tambah Kategori'),
          ),
        ),
      ],
    );
  }
}

// ==========================================================
// FORMATTER ANGKA RIBUAN
// ==========================================================
class _ThousandFormatter extends TextInputFormatter {
  final NumberFormat _formatter = NumberFormat.decimalPattern('id');

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue;
    
    // Hapus titik pemisah untuk mendapatkan angka murni
    String cleanText = newValue.text.replaceAll('.', '');
    if (cleanText.isEmpty) return newValue.copyWith(text: '');

    final int? value = int.tryParse(cleanText);
    if (value == null) return oldValue;

    // Format kembali dengan titik
    final String formatted = _formatter.format(value);
    
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

// ==========================================================
// DIALOG PRODUK
// ==========================================================
class _ProductDialog extends StatefulWidget {
  final Product? existing;
  final List<Category> categories;
  final SupabaseService service;

  const _ProductDialog({
    this.existing,
    required this.categories,
    required this.service,
  });

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
  
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existing?.name ?? '');
    
    // Setup Formatter Harga
    final formatCurrency = NumberFormat.decimalPattern('id');
    _priceController = TextEditingController(
      text: widget.existing != null ? formatCurrency.format(widget.existing!.price) : '',
    );
    _hppController = TextEditingController(
      text: widget.existing != null ? formatCurrency.format(widget.existing!.hpp) : '',
    );
    
    _selectedCategoryId = widget.existing?.categoryId;
    _existingImageUrl = widget.existing?.imageUrl;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _hppController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
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
      // Parse harga & HPP dengan menghapus titik
      final price = int.parse(_priceController.text.replaceAll('.', ''));
      final hpp = int.parse(_hppController.text.replaceAll('.', ''));
      
      String? finalImageUrl = _existingImageUrl;
      
      // Upload gambar baru jika ada
      if (_imageFile != null) {
        finalImageUrl = await widget.service.uploadProductImage(_imageFile!);
      }

      if (widget.existing == null) {
        await widget.service.createProduct(
          name: name,
          price: price,
          hpp: hpp,
          categoryId: _selectedCategoryId,
          imageUrl: finalImageUrl,
        );
      } else {
        await widget.service.updateProduct(
          id: widget.existing!.id,
          name: name,
          price: price,
          hpp: hpp,
          categoryId: _selectedCategoryId,
          imageUrl: finalImageUrl,
        );
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _errorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: AppTheme.dangerColor, fontSize: 12),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              
              // Image Picker
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
                      image: _imageFile != null
                          ? DecorationImage(image: FileImage(_imageFile!), fit: BoxFit.cover)
                          : _existingImageUrl != null
                              ? DecorationImage(image: NetworkImage(_existingImageUrl!), fit: BoxFit.cover)
                              : null,
                    ),
                    child: (_imageFile == null && _existingImageUrl == null)
                        ? const Icon(Icons.add_a_photo_outlined, color: AppTheme.textLightColor, size: 32)
                        : null,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Nama Produk'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Nama wajib diisi' : null,
              ),
              const SizedBox(height: 12),
              
              // HPP Input
              TextFormField(
                controller: _hppController,
                keyboardType: TextInputType.number,
                inputFormatters: [_ThousandFormatter()],
                decoration: const InputDecoration(
                  labelText: 'HPP (Harga Modal)',
                  prefixText: 'Rp ',
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'HPP wajib diisi';
                  final n = int.tryParse(v.trim().replaceAll('.', ''));
                  if (n == null || n < 0) return 'HPP tidak valid';
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Harga Jual Input
              TextFormField(
                controller: _priceController,
                keyboardType: TextInputType.number,
                inputFormatters: [_ThousandFormatter()],
                decoration: const InputDecoration(
                  labelText: 'Harga Jual',
                  prefixText: 'Rp ',
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Harga jual wajib diisi';
                  final n = int.tryParse(v.trim().replaceAll('.', ''));
                  if (n == null || n < 0) return 'Harga tidak valid';
                  return null;
                },
              ),
              const SizedBox(height: 12),

              DropdownButtonFormField<int?>(
                value: _selectedCategoryId,
                decoration: const InputDecoration(labelText: 'Kategori (opsional)'),
                items: [
                  const DropdownMenuItem<int?>(value: null, child: Text('Tanpa Kategori')),
                  ...widget.categories.map((c) => DropdownMenuItem<int?>(value: c.id, child: Text(c.name))),
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
          child: const Text('BATAL'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('SIMPAN'),
        ),
      ],
    );
  }
}

// ==========================================================
// DIALOG KATEGORI
// ==========================================================
class _CategoryDialog extends StatefulWidget {
  final Category? existing;
  final SupabaseService service;

  const _CategoryDialog({
    this.existing,
    required this.service,
  });

  @override
  State<_CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends State<_CategoryDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existing?.name ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });
    try {
      final name = _nameController.text.trim();
      if (widget.existing == null) {
        await widget.service.createCategory(name);
      } else {
        await widget.service.updateCategory(id: widget.existing!.id, name: name);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _errorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      title: Text(widget.existing == null ? 'Tambah Kategori' : 'Edit Kategori'),
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
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: AppTheme.dangerColor, fontSize: 12),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Nama Kategori'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Nama wajib diisi' : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context, false),
          child: const Text('BATAL'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('SIMPAN'),
        ),
      ],
    );
  }
}