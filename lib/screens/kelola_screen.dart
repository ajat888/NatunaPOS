// lib/screens/kelola_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import '../core/theme.dart';
import '../models/product.dart';
import '../models/category.dart';
import '../services/supabase_service.dart';
import '../widgets/common/thousand_formatter.dart';

part 'kelola/product_dialog.dart';
part 'kelola/category_dialog.dart';

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
  int? _filterCategoryId;
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
    if (mounted) setState(() { _isLoading = true; _errorMessage = null; });

    try {
      final products = await _service.getLocalProducts();
      final categories = await _service.getLocalCategories();
      if (!mounted) return;
      setState(() {
        _products = products;
        _categories = categories;
        _isLoading = false;
      });

      _service.syncData().then((_) async {
        try {
          final p = await _service.getLocalProducts();
          final c = await _service.getLocalCategories();
          if (!mounted) return;
          setState(() { _products = p; _categories = c; });
        } catch (e) {
          debugPrint('Reload after sync failed: $e');
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Gagal memuat data lokal.';
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
      builder: (_) => _CategoryDialog(existing: existing, service: _service),
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
              child: const Text('BATAL')),
          ElevatedButton(
              style:
                  ElevatedButton.styleFrom(backgroundColor: AppTheme.dangerColor),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('HAPUS')),
        ],
      ),
    );
    if (confirmed != true) return;
    await _service.deleteProduct(product.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Produk dihapus'), backgroundColor: Colors.green));
    await _loadAll();
  }

  Future<void> _confirmDeleteCategory(Category category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        title: const Text('Hapus Kategori'),
        content: Text('Yakin ingin menghapus kategori "${category.name}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('BATAL')),
          ElevatedButton(
              style:
                  ElevatedButton.styleFrom(backgroundColor: AppTheme.dangerColor),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('HAPUS')),
        ],
      ),
    );
    if (confirmed != true) return;
    await _service.deleteCategory(category.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kategori dihapus'), backgroundColor: Colors.green));
    await _loadAll();
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
              tooltip: 'Muat ulang')
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: AppTheme.textLightColor,
          indicatorColor: AppTheme.primaryColor,
          labelStyle:
              const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
          tabs: const [Tab(text: 'PRODUK'), Tab(text: 'KATEGORI')],
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
                          style: const TextStyle(color: AppTheme.dangerColor)),
                      const SizedBox(height: 16),
                      TextButton(
                          onPressed: _loadAll,
                          child: const Text('Coba Lagi'))
                    ]))
              : TabBarView(controller: _tabController, children: [
                  _buildProductsTab(),
                  _buildCategoriesTab(),
                ]),
    );
  }

  Widget _buildProductsTab() {
    return Stack(
      children: [
        Column(
          children: [
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
                        onSelected: (val) =>
                            setState(() => _filterCategoryId = null)),
                    const SizedBox(width: 8),
                    ..._categories.map((c) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                            label: Text(c.name),
                            selected: _filterCategoryId == c.id,
                            onSelected: (val) =>
                                setState(() => _filterCategoryId = c.id)))),
                  ],
                ),
              ),
            Expanded(
              child: _filteredProducts.isEmpty
                  ? const Center(
                      child: Text('Tidak ada produk di kategori ini.',
                          style: TextStyle(color: AppTheme.textLightColor)))
                  : GridView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 220,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 0.75),
                      itemCount: _filteredProducts.length,
                      itemBuilder: (context, index) {
                        final product = _filteredProducts[index];
                        return Container(
                          decoration: BoxDecoration(
                              color: AppTheme.surfaceColor,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: const Color(0xFFE2E8F0))),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                  child: ClipRRect(
                                      borderRadius: const BorderRadius.vertical(
                                          top: Radius.circular(8)),
                                      child: _buildProductImage(product))),
                              Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                            child: Text(product.name,
                                                style: const TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    color: AppTheme.textColor),
                                                maxLines: 1,
                                                overflow:
                                                    TextOverflow.ellipsis)),
                                        if (!product.isSynced)
                                          const Icon(Icons.cloud_off,
                                              size: 14,
                                              color: AppTheme.dangerColor),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                        'Rp ${NumberFormat.decimalPattern('id').format(product.price)}',
                                        style: const TextStyle(
                                            fontSize: 13,
                                            color: AppTheme.primaryColor,
                                            fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 8),
                                    Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        children: [
                                          InkWell(
                                              onTap: () =>
                                                  _showProductDialog(
                                                      existing: product),
                                              child: const Icon(
                                                  Icons.edit_outlined,
                                                  color:
                                                      AppTheme.primaryColor,
                                                  size: 20)),
                                          const SizedBox(width: 12),
                                          InkWell(
                                              onTap: () =>
                                                  _confirmDeleteProduct(product),
                                              child: const Icon(
                                                  Icons.delete_outline,
                                                  color: AppTheme.dangerColor,
                                                  size: 20)),
                                        ])
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
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                onPressed: () => _showProductDialog(),
                icon: const Icon(Icons.add),
                label: const Text('Tambah Produk'))),
      ],
    );
  }

  Widget _buildProductImage(Product product) {
    if (product.localImagePath != null &&
        File(product.localImagePath!).existsSync()) {
      return Image.file(File(product.localImagePath!), fit: BoxFit.cover);
    }
    if (product.imageUrl != null && product.imageUrl!.isNotEmpty) {
      return Image.network(product.imageUrl!,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildImagePlaceholder());
    }
    return _buildImagePlaceholder();
  }

  Widget _buildImagePlaceholder() => Container(
      color: const Color(0xFFF1F5F9),
      child: const Center(
          child: Icon(Icons.image_outlined,
              color: AppTheme.textLightColor, size: 40)));

  Widget _buildCategoriesTab() {
    return Stack(
      children: [
        _categories.isEmpty
            ? const Center(
                child: Text('Belum ada kategori. Tambahkan kategori pertama Anda.',
                    style: TextStyle(color: AppTheme.textLightColor)))
            : ListView.separated(
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
                        border: Border.all(color: const Color(0xFFE2E8F0))),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      title: Text(category.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textColor)),
                      subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text('$count produk',
                              style: const TextStyle(
                                  color: AppTheme.textLightColor,
                                  fontSize: 13))),
                      trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                                icon: const Icon(Icons.edit_outlined,
                                    color: AppTheme.primaryColor),
                                onPressed: () =>
                                    _showCategoryDialog(existing: category),
                                tooltip: 'Edit'),
                            IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    color: AppTheme.dangerColor),
                                onPressed: () =>
                                    _confirmDeleteCategory(category),
                                tooltip: 'Hapus'),
                          ]),
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
                label: const Text('Tambah Kategori'))),
      ],
    );
  }
}