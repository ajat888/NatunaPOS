part of '../kelola_screen.dart';

class _ProductsTab extends StatelessWidget {
  final KelolaScreenState state;
  const _ProductsTab({required this.state});

  List<Product> get _filteredProducts {
    final base = state._showInactive ? state._inactiveProducts : state._products;
    if (state._filterCategoryId == null) return base;
    if (state._filterCategoryId == -1) return base.where((p) => p.categoryId == null).toList();
    return base.where((p) => p.categoryId == state._filterCategoryId).toList();
  }

  Future<void> _showProductDialog(BuildContext context, {Product? existing}) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ProductDialog(
        existing: existing,
        categories: state._categories,
        service: state._service,
      ),
    );
    if (result == true) await state.reloadData();
  }

  Future<void> _confirmDeleteProduct(BuildContext context, Product product) async {
    final isRestoring = state._showInactive;
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
      await state._service.restoreProduct(product.id);
    } else {
      await state._service.deleteProduct(product.id);
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(isRestoring ? 'Produk diaktifkan kembali' : 'Produk dinonaktifkan'),
        backgroundColor: Colors.green));
    await state.reloadData();
  }

  @override
  Widget build(BuildContext context) {
    final baseProducts = state._showInactive ? state._inactiveProducts : state._products;
    final activeCategories = state._categories.where((c) {
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
                                selected: state._filterCategoryId == c.id,
                                onSelected: (val) {
                                  state.setState(() {
                                    state._filterCategoryId = state._filterCategoryId == c.id ? null : c.id;
                                  });
                                }))),
                        if (hasUncategorized)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                                label: const Text('Tanpa Kategori'),
                                selected: state._filterCategoryId == -1,
                                onSelected: (val) {
                                  state.setState(() {
                                    state._filterCategoryId = state._filterCategoryId == -1 ? null : -1;
                                  });
                                })),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () => state.setState(() {
                      state._showInactive = !state._showInactive;
                      state._filterCategoryId = null; 
                    }),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: state._showInactive ? AppTheme.dangerColor.withOpacity(0.1) : AppTheme.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: state._showInactive ? AppTheme.dangerColor : AppTheme.primaryColor),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(state._showInactive ? Icons.visibility_off : Icons.visibility, size: 14, color: state._showInactive ? AppTheme.dangerColor : AppTheme.primaryColor),
                          const SizedBox(width: 4),
                          Text(
                            state._showInactive ? 'Nonaktif' : 'Aktif',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: state._showInactive ? AppTheme.dangerColor : AppTheme.primaryColor,
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
                          state._showInactive 
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
                          isInactive: state._showInactive,
                          onEdit: () => _showProductDialog(context, existing: product),
                          onDeleteRestore: () => _confirmDeleteProduct(context, product),
                        );
                      },
                    ),
            ),
          ],
        ),
        if (!state._showInactive)
          Positioned(
              right: 16,
              bottom: 16,
              child: FloatingActionButton.extended(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  onPressed: () => _showProductDialog(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Tambah Produk'))),
      ],
    );
  }
}