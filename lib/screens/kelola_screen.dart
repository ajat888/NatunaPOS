import 'package:flutter/material.dart';
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
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.dangerColor),
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
        const SnackBar(
            content: Text('Produk dihapus'), backgroundColor: Colors.green),
      );
      await _loadAll();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _confirmDeleteCategory(Category category) async {
    final affected =
        _products.where((p) => p.categoryId == category.id).length;
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
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.dangerColor),
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
        const SnackBar(
            content: Text('Kategori dihapus'),
            backgroundColor: Colors.green),
      );
      await _loadAll();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
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
          labelStyle:
              const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
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
                      Text(_errorMessage!,
                          style:
                              const TextStyle(color: AppTheme.dangerColor)),
                      const SizedBox(height: 16),
                      TextButton(
                          onPressed: _loadAll,
                          child: const Text('Coba Lagi')),
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
        _products.isEmpty
            ? const Center(
                child: Text(
                  'Belum ada produk. Tambahkan produk pertama Anda.',
                  style: TextStyle(color: AppTheme.textLightColor),
                ),
              )
            : ListView.separated(
                // Padding bawah diperbesar menjadi 120 agar tidak tertutup FAB
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                itemCount: _products.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final product = _products[index];
                  final catName = _categoryName(product.categoryId);
                  return Container(
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceColor,
                      borderRadius: BorderRadius.circular(8),
                      border:
                          Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      title: Text(
                        product.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textColor,
                        ),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Rp ${product.price}${catName != null ? '  •  $catName' : ''}',
                          style: const TextStyle(
                              color: AppTheme.textLightColor, fontSize: 13),
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined,
                                color: AppTheme.primaryColor),
                            onPressed: () =>
                                _showProductDialog(existing: product),
                            tooltip: 'Edit',
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline,
                                color: AppTheme.dangerColor),
                            onPressed: () =>
                                _confirmDeleteProduct(product),
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
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
            onPressed: () => _showProductDialog(),
            icon: const Icon(Icons.add),
            label: const Text('Tambah Produk'),
          ),
        ),
      ],
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
                // Padding bawah diperbesar menjadi 120 agar tidak tertutup FAB
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                itemCount: _categories.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final category = _categories[index];
                  final count = _products
                      .where((p) => p.categoryId == category.id)
                      .length;
                  return Container(
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceColor,
                      borderRadius: BorderRadius.circular(8),
                      border:
                          Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      title: Text(
                        category.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textColor,
                        ),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '$count produk',
                          style: const TextStyle(
                              color: AppTheme.textLightColor, fontSize: 13),
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined,
                                color: AppTheme.primaryColor),
                            onPressed: () =>
                                _showCategoryDialog(existing: category),
                            tooltip: 'Edit',
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline,
                                color: AppTheme.dangerColor),
                            onPressed: () =>
                                _confirmDeleteCategory(category),
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
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
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
  int? _selectedCategoryId;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _nameController =
        TextEditingController(text: widget.existing?.name ?? '');
    _priceController = TextEditingController(
      text: widget.existing?.price.toString() ?? '',
    );
    _selectedCategoryId = widget.existing?.categoryId;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
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
      final price = int.parse(_priceController.text.trim());
      if (widget.existing == null) {
        await widget.service.createProduct(
          name: name,
          price: price,
          categoryId: _selectedCategoryId,
        );
      } else {
        await widget.service.updateProduct(
          id: widget.existing!.id,
          name: name,
          price: price,
          categoryId: _selectedCategoryId,
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      title: Text(widget.existing == null ? 'Tambah Produk' : 'Edit Produk'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
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
                      style: const TextStyle(
                          color: AppTheme.dangerColor, fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                TextFormField(
                  controller: _nameController,
                  decoration:
                      const InputDecoration(labelText: 'Nama Produk'),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Nama wajib diisi'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _priceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Harga',
                    prefixText: 'Rp ',
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Harga wajib diisi';
                    }
                    final n = int.tryParse(v.trim());
                    if (n == null || n < 0) return 'Harga tidak valid';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int?>(
                  value: _selectedCategoryId,
                  decoration: const InputDecoration(
                      labelText: 'Kategori (opsional)'),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('Tanpa Kategori'),
                    ),
                    ...widget.categories.map(
                      (c) => DropdownMenuItem<int?>(
                        value: c.id,
                        child: Text(c.name),
                      ),
                    ),
                  ],
                  onChanged: (v) => setState(() => _selectedCategoryId = v),
                ),
              ],
            ),
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
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2),
                )
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
    _nameController =
        TextEditingController(text: widget.existing?.name ?? '');
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
        await widget.service
            .updateCategory(id: widget.existing!.id, name: name);
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      title:
          Text(widget.existing == null ? 'Tambah Kategori' : 'Edit Kategori'),
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
                    style: const TextStyle(
                        color: AppTheme.dangerColor, fontSize: 12),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              TextFormField(
                controller: _nameController,
                decoration:
                    const InputDecoration(labelText: 'Nama Kategori'),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Nama wajib diisi'
                    : null,
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
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2),
                )
              : const Text('SIMPAN'),
        ),
      ],
    );
  }
}