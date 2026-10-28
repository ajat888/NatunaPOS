import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/supabase_service.dart';
import '../models/product.dart';
import '../models/transaction.dart';
import '../core/theme.dart';

part 'pos/checkout_dialog.dart';

class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  final _service = SupabaseService();
  List<Product> _products = [];
  final Map<int, int> _cart = {};
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }
    try {
      final products = await _service.getLocalProducts();
      if (!mounted) return;
      final previous = _products;
      _remapCart(previousProducts: previous, newProducts: products);
      setState(() {
        _products = products;
        _isLoading = false;
      });

      _service.syncData().then((_) async {
        if (!mounted) return;
        try {
          final updated = await _service.getLocalProducts();
          if (!mounted) return;
          final beforeSync = _products;
          _remapCart(previousProducts: beforeSync, newProducts: updated);
          setState(() => _products = updated);
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

  void _remapCart({
    required List<Product> previousProducts,
    required List<Product> newProducts,
  }) {
    if (_cart.isEmpty) return;
    final newIds = newProducts.map((p) => p.id).toSet();
    final newCart = <int, int>{};

    _cart.forEach((oldId, qty) {
      if (newIds.contains(oldId)) {
        newCart[oldId] = (newCart[oldId] ?? 0) + qty;
        return;
      }
      Product? oldProduct;
      for (final p in previousProducts) {
        if (p.id == oldId) {
          oldProduct = p;
          break;
        }
      }
      if (oldProduct == null) return;
      Product? replacement;
      for (final p in newProducts) {
        if (p.name == oldProduct.name &&
            p.price == oldProduct.price &&
            p.hpp == oldProduct.hpp &&
            p.categoryId == oldProduct.categoryId) {
          replacement = p;
          break;
        }
      }
      if (replacement != null) {
        newCart[replacement.id] = (newCart[replacement.id] ?? 0) + qty;
      }
    });

    _cart
      ..clear()
      ..addAll(newCart);
  }

  Product? _findProduct(int id) {
    for (final p in _products) {
      if (p.id == id) return p;
    }
    return null;
  }

  void _addToCart(Product product) =>
      setState(() => _cart[product.id] = (_cart[product.id] ?? 0) + 1);

  void _removeFromCart(Product product) {
    setState(() {
      final qty = _cart[product.id] ?? 0;
      if (qty <= 1) {
        _cart.remove(product.id);
      } else {
        _cart[product.id] = qty - 1;
      }
    });
  }

  int get _totalPrice {
    int total = 0;
    _cart.forEach((id, qty) {
      final p = _findProduct(id);
      if (p != null) total += p.price * qty;
    });
    return total;
  }

  int get _totalItems {
    int total = 0;
    _cart.forEach((id, qty) {
      if (_findProduct(id) != null) total += qty;
    });
    return total;
  }

  void _showCheckoutDialog() {
    if (_cart.isEmpty) return;

    final snapshot = <TransactionLine>[];
    int totalPrice = 0;
    _cart.forEach((id, qty) {
      final p = _findProduct(id);
      if (p == null) return;
      snapshot.add(TransactionLine(
        productId: p.id,
        productName: p.name,
        price: p.price,
        hpp: p.hpp,
        qty: qty,
      ));
      totalPrice += p.price * qty;
    });

    if (snapshot.isEmpty) {
      setState(() => _cart.clear());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Produk di keranjang sudah tidak tersedia.'),
          backgroundColor: AppTheme.dangerColor,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _CheckoutDialog(
        lines: snapshot,
        total: totalPrice,
        service: _service,
        onSuccess: () {
          if (!mounted) return;
          setState(() => _cart.clear());
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Transaksi Berhasil!'),
              backgroundColor: Colors.green,
            ),
          );
        },
      ),
    );
  }

  void _showCartSheet() {
    final formatCurrency = NumberFormat.decimalPattern('id');
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceColor,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(8))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: SizedBox(
                width: double.infinity,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('Keranjang Belanja',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16))),
                    const Divider(height: 1),
                    Flexible(
                      child: _cart.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.all(24),
                              child: Text('Keranjang kosong',
                                  style: TextStyle(
                                      color: AppTheme.textLightColor)))
                          : ListView(
                              shrinkWrap: true,
                              children: _cart.entries.map((entry) {
                                final product = _findProduct(entry.key);
                                if (product == null) {
                                  return const SizedBox.shrink();
                                }
                                return ListTile(
                                  title: Text(product.name),
                                  subtitle: Text(
                                      'Rp ${formatCurrency.format(product.price)} x ${entry.value}'),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                          icon: const Icon(
                                              Icons.remove_circle_outline),
                                          onPressed: () {
                                            _removeFromCart(product);
                                            setSheetState(() {});
                                          }),
                                      Text('${entry.value}'),
                                      IconButton(
                                          icon: const Icon(
                                              Icons.add_circle_outline),
                                          onPressed: () {
                                            _addToCart(product);
                                            setSheetState(() {});
                                          }),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
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

  @override
  Widget build(BuildContext context) {
    final formatCurrency = NumberFormat.decimalPattern('id');
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
          title: const Text('Kasir'),
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loadProducts,
                tooltip: 'Muat ulang produk')
          ]),
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
                          onPressed: _loadProducts,
                          child: const Text('Coba Lagi'))
                    ]))
              : _products.isEmpty
                  ? const Center(child: Text('Belum ada data produk.'))
                  : GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 220,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 0.75),
                      itemCount: _products.length,
                      itemBuilder: (context, index) {
                        final product = _products[index];
                        final qty = _cart[product.id] ?? 0;
                        return Container(
                          decoration: BoxDecoration(
                              color: AppTheme.surfaceColor,
                              borderRadius: BorderRadius.circular(8),
                              border:
                                  Border.all(color: const Color(0xFFE2E8F0))),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () => _addToCart(product),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(8)),
                                    child: Stack(fit: StackFit.expand, children: [
                                      _buildProductImage(product),
                                      if (qty > 0)
                                        Positioned(
                                            top: 8,
                                            right: 8,
                                            child: Container(
                                                padding:
                                                    const EdgeInsets.all(6),
                                                decoration: const BoxDecoration(
                                                    color: AppTheme.primaryColor,
                                                    shape: BoxShape.circle),
                                                child: Text('$qty',
                                                    style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.bold)))),
                                    ]),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(product.name,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                color: AppTheme.textColor),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis),
                                        const SizedBox(height: 4),
                                        Text(
                                            'Rp ${formatCurrency.format(product.price)}',
                                            style: const TextStyle(
                                                fontSize: 13,
                                                color: AppTheme.primaryColor,
                                                fontWeight: FontWeight.bold)),
                                      ]),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
      bottomNavigationBar:
          _cart.isEmpty ? null : _buildBottomBar(formatCurrency),
    );
  }

  Widget _buildBottomBar(NumberFormat formatCurrency) {
    return GestureDetector(
      onTap: _showCartSheet,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: const BoxDecoration(
            color: AppTheme.surfaceColor,
            border: Border(top: BorderSide(color: Color(0xFFE2E8F0)))),
        child: SafeArea(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$_totalItems Barang (ketuk untuk detail)',
                        style: const TextStyle(
                            color: AppTheme.textLightColor, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text('Rp ${formatCurrency.format(_totalPrice)}',
                        style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textColor)),
                  ]),
              ElevatedButton(
                  onPressed: _showCheckoutDialog,
                  style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 40, vertical: 16)),
                  child: const Text('BAYAR')),
            ],
          ),
        ),
      ),
    );
  }
}