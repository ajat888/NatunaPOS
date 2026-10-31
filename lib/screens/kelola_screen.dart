// lib/screens/kelola_screen.dart
import 'dart:async';
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
import '../widgets/common/main_menu_scope.dart';
import '../widgets/common/thousand_formatter.dart';

part 'kelola/product_dialog.dart';
part 'kelola/category_dialog.dart';
part 'kelola/product_card.dart';

class KelolaScreen extends StatefulWidget {
  const KelolaScreen({super.key});

  @override
  State<KelolaScreen> createState() => KelolaScreenState();
}

class KelolaScreenState extends State<KelolaScreen>
    with SingleTickerProviderStateMixin {
  final _service = SupabaseService();
  late final TabController _tabController;

  List<Product> _products = [];
  List<Product> _inactiveProducts = [];
  List<Category> _categories = [];
  int? _filterCategoryId;
  bool _showInactive = false;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    reloadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> reloadData() async {
    if (mounted) setState(() { _isLoading = true; _errorMessage = null; });

    try {
      final products = await _service.getLocalProducts();
      final inactiveProducts = await _service.getLocalInactiveProducts();
      final categories = await _service.getLocalCategories();
      if (!mounted) return;

      // Validasi filter jika kategori tersebut sudah kosong / terhapus
      final base = _showInactive ? inactiveProducts : products;
      if (_filterCategoryId != null && _filterCategoryId != -1) {
        final hasCat = categories.any((c) => c.id == _filterCategoryId) && 
                       base.any((p) => p.categoryId == _filterCategoryId);
        if (!hasCat) _filterCategoryId = null;
      }

      setState(() {
        _products = products;
        _inactiveProducts = inactiveProducts;
        _categories = categories;
        _isLoading = false;
      });

      _service.syncData().then((_) async {
        try {
          final p = await _service.getLocalProducts();
          final ip = await _service.getLocalInactiveProducts();
          final c = await _service.getLocalCategories();
          if (!mounted) return;
          setState(() {
            _products = p;
            _inactiveProducts = ip;
            _categories = c;
          });
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

  List<Product> get _filteredProducts {
    final base = _showInactive ? _inactiveProducts : _products;
    if (_filterCategoryId == null) return base;
    if (_filterCategoryId == -1) return base.where((p) => p.categoryId == null).toList();
    return base.where((p) => p.categoryId == _filterCategoryId).toList();
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
    if (result == true) await reloadData();
  }

  Future<void> _showCategoryDialog({Category? existing}) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _CategoryDialog(existing: existing, service: _service),
    );
    if (result == true) await reloadData();
  }

  Future<void> _confirmDeleteProduct(Product product) async {
    final isRestoring = _showInactive;
    final title = isRestoring ? 'Aktifkan Produk' : 'Nonaktifkan Produk';
    final content = isRestoring
        ? 'Yakin ingin mengaktifkan kembali "${product.name}"?'
        : 'Yakin ingin menonaktifkan "${product.name}"?\nProduk tidak akan muncul di kasir.';
    final confirmText = isRestoring ? 'AKTIFKAN' : 'NONAKTIFKAN';
    final btnColor = isRestoring ? Colors.green : AppTheme.dangerColor;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('BATAL')),
          ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: btnColor),
              onPressed: () => Navigator.pop(context, true),
              child: Text(confirmText)),
        ],
      ),
    );
    if (confirmed != true) return;

    if (isRestoring) {
      await _service.restoreProduct(product.id);
    } else {
      await _service.deleteProduct(product.id);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            isRestoring ? 'Produk diaktifkan kembali' : 'Produk dinonaktifkan'),
        backgroundColor: Colors.green));
    await reloadData();
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
    await reloadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          tooltip: 'Menu',
          onPressed: () => MainMenuScope.of(context)?.openMenu(),
        ),
        title: const Text('Kelola Data'),
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: reloadData,
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
                          onPressed: reloadData,
                          child: const Text('Coba Lagi'))
                    ]))
              : TabBarView(controller: _tabController, children: [
                  _buildProductsTab(),
                  _buildCategoriesTab(),
                ]),
    );
  }

  Widget _buildProductsTab() {
    final baseProducts = _showInactive ? _inactiveProducts : _products;
    
    // Hanya tampilkan kategori yang punya produk
    final activeCategories = _categories.where((c) {
      return baseProducts.any((p) => p.categoryId == c.id);
    }).toList();
    
    final hasUncategorized = baseProducts.any((p) => p.categoryId == null);

    return Stack(
      children: [
        Column(
          children: [
            Container(
              height: 50,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        ...activeCategories.map((c) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                                label: Text(c.name),
                                selected: _filterCategoryId == c.id,
                                onSelected: (val) {
                                  setState(() {
                                    _filterCategoryId = _filterCategoryId == c.id ? null : c.id;
                                  });
                                }))),
                        if (hasUncategorized)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                                label: const Text('Tanpa Kategori'),
                                selected: _filterCategoryId == -1,
                                onSelected: (val) {
                                  setState(() {
                                    _filterCategoryId = _filterCategoryId == -1 ? null : -1;
                                  });
                                })),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () => setState(() {
                      _showInactive = !_showInactive;
                      _filterCategoryId = null; // Reset filter saat ganti tab
                    }),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _showInactive ? AppTheme.dangerColor.withOpacity(0.1) : AppTheme.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _showInactive ? AppTheme.dangerColor : AppTheme.primaryColor),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_showInactive ? Icons.visibility_off : Icons.visibility, size: 14, color: _showInactive ? AppTheme.dangerColor : AppTheme.primaryColor),
                          const SizedBox(width: 4),
                          Text(
                            _showInactive ? 'Nonaktif' : 'Aktif',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _showInactive ? AppTheme.dangerColor : AppTheme.primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _filteredProducts.isEmpty
                  ? Center(
                      child: Text(
                          _showInactive 
                              ? 'Tidak ada produk nonaktif.' 
                              : 'Tidak ada produk di kategori ini.',
                          style: const TextStyle(color: AppTheme.textLightColor)))
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
                        return _ProductCard(
                          product: product,
                          isInactive: _showInactive,
                          onEdit: () => _showProductDialog(existing: product),
                          onDeleteRestore: () => _confirmDeleteProduct(product),
                        );
                      },
                    ),
            ),
          ],
        ),
        if (!_showInactive)
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