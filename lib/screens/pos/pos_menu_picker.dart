// lib/screens/pos/pos_menu_picker.dart
part of '../pos_screen.dart';

class _PosMenuPicker extends StatelessWidget {
  final List<Product> products;
  final List<Category> categories;
  final Map<int, int> cart;
  final int? filterCategoryId;
  final void Function(int? categoryId) onFilterChanged;
  final void Function(Product product) onAdd;
  final void Function(Product product) onRemove;
  final int cartTotal;
  final int cartItemCount;
  final VoidCallback onSave;
  final VoidCallback onBack;
  final String title;

  const _PosMenuPicker({
    required this.products,
    required this.categories,
    required this.cart,
    required this.filterCategoryId,
    required this.onFilterChanged,
    required this.onAdd,
    required this.onRemove,
    required this.cartTotal,
    required this.cartItemCount,
    required this.onSave,
    required this.onBack,
    required this.title,
  });

  List<Product> get _filteredProducts {
    if (filterCategoryId == null) return products;
    return products.where((p) => p.categoryId == filterCategoryId).toList();
  }

  @override
  Widget build(BuildContext context) {
    final formatCurrency = NumberFormat.decimalPattern('id');
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: onBack),
        title: Text(title),
        automaticallyImplyLeading: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text('$cartItemCount item',
                  style: const TextStyle(
                      color: AppTheme.textLightColor, fontSize: 13)),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (categories.isNotEmpty)
            Container(
              height: 50,
              padding: const EdgeInsets.symmetric(vertical: 8),
              color: AppTheme.surfaceColor,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  ChoiceChip(
                    label: const Text('Semua'),
                    selected: filterCategoryId == null,
                    onSelected: (_) => onFilterChanged(null),
                  ),
                  const SizedBox(width: 8),
                  ...categories.map((c) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(c.name),
                          selected: filterCategoryId == c.id,
                          onSelected: (_) => onFilterChanged(c.id),
                        ),
                      )),
                ],
              ),
            ),
          Expanded(
            child: _filteredProducts.isEmpty
                ? const Center(
                    child: Text('Tidak ada produk.',
                        style: TextStyle(color: AppTheme.textLightColor)))
                : GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 200,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.75,
                    ),
                    itemCount: _filteredProducts.length,
                    itemBuilder: (context, i) {
                      final p = _filteredProducts[i];
                      final qty = cart[p.id] ?? 0;
                      return _ProductCard(
                        product: p,
                        qty: qty,
                        onAdd: () => onAdd(p),
                        onRemove: () => onRemove(p),
                      );
                    },
                  ),
          ),
          if (cart.isNotEmpty) _buildBottomBar(formatCurrency),
        ],
      ),
    );
  }

  Widget _buildBottomBar(NumberFormat formatCurrency) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: const BoxDecoration(
        color: AppTheme.surfaceColor,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$cartItemCount item',
                    style: const TextStyle(
                        color: AppTheme.textLightColor, fontSize: 12)),
                const SizedBox(height: 2),
                Text('Rp ${formatCurrency.format(cartTotal)}',
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textColor)),
              ],
            ),
            ElevatedButton(
              onPressed: onSave,
              style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 14)),
              child: const Text('SIMPAN'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Product product;
  final int qty;
  final VoidCallback onAdd;
  final VoidCallback onRemove;
  const _ProductCard({
    required this.product,
    required this.qty,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final formatCurrency = NumberFormat.decimalPattern('id');
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(8)),
                  child: InkWell(onTap: onAdd, child: _buildImage()),
                ),
                if (qty > 0)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                          color: AppTheme.primaryColor,
                          borderRadius: BorderRadius.circular(12)),
                      child: Text('$qty',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textColor,
                        fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text('Rp ${formatCurrency.format(product.price)}',
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (qty > 0)
                      InkWell(
                        onTap: onRemove,
                        child: const Icon(Icons.remove_circle_outline,
                            color: AppTheme.dangerColor, size: 22),
                      ),
                    if (qty > 0) const SizedBox(width: 8),
                    InkWell(
                      onTap: onAdd,
                      child: const Icon(Icons.add_circle,
                          color: AppTheme.primaryColor, size: 22),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImage() {
    if (product.localImagePath != null &&
        File(product.localImagePath!).existsSync()) {
      return Image.file(File(product.localImagePath!), fit: BoxFit.cover);
    }
    if (product.imageUrl != null && product.imageUrl!.isNotEmpty) {
      return Image.network(product.imageUrl!,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _placeholder());
    }
    return _placeholder();
  }

  Widget _placeholder() => Container(
        color: const Color(0xFFF1F5F9),
        child: const Center(
            child: Icon(Icons.image_outlined,
                color: AppTheme.textLightColor, size: 32)),
      );
}