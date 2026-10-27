import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/supabase_service.dart';
import '../models/product.dart';
import '../core/theme.dart';

class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  final _service = SupabaseService();
  List<Product> _products = [];
  // Cart pakai productId sebagai key -> aman walau Product object diganti
  final Map<int, int> _cart = {};
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final products = await _service.fetchProducts();
      if (!mounted) return;
      final validIds = products.map((p) => p.id).toSet();
      setState(() {
        _products = products;
        // Bersihkan cart dari produk yang sudah tidak ada
        _cart.removeWhere((id, _) => !validIds.contains(id));
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Gagal memuat produk.';
      });
    }
  }

  Product? _findProduct(int id) {
    for (final p in _products) {
      if (p.id == id) return p;
    }
    return null;
  }

  void _addToCart(Product product) {
    setState(() {
      _cart[product.id] = (_cart[product.id] ?? 0) + 1;
    });
  }

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
    final formatCurrency = NumberFormat.decimalPattern('id');
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        title: const Text('Konfirmasi Pembayaran'),
        content: Text(
            'Total tagihan: Rp ${formatCurrency.format(_totalPrice)}\n\nLanjutkan proses pembayaran?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('BATAL',
                style: TextStyle(color: AppTheme.textLightColor)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => _cart.clear());
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Transaksi Berhasil!'),
                    backgroundColor: Colors.green),
              );
            },
            child: const Text('BAYAR'),
          ),
        ],
      ),
    );
  }

  void _showCartSheet() {
    final formatCurrency = NumberFormat.decimalPattern('id');
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
      ),
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
                      child: Text(
                        'Keranjang Belanja',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                    const Divider(height: 1),
                    Flexible(
                      child: _cart.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.all(24),
                              child: Text('Keranjang kosong',
                                  style: TextStyle(
                                      color: AppTheme.textLightColor)),
                            )
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
                                        },
                                      ),
                                      Text('${entry.value}'),
                                      IconButton(
                                        icon: const Icon(
                                            Icons.add_circle_outline),
                                        onPressed: () {
                                          _addToCart(product);
                                          setSheetState(() {});
                                        },
                                      ),
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
    // 1. Prioritas Utama: File Lokal (jika offline atau belum di-upload)
    if (product.localImagePath != null && File(product.localImagePath!).existsSync()) {
      return Image.file(File(product.localImagePath!), fit: BoxFit.cover);
    }
    // 2. Jika sudah di-upload dan ada URL
    if (product.imageUrl != null && product.imageUrl!.isNotEmpty) {
      return Image.network(
        product.imageUrl!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildImagePlaceholder(),
      );
    }
    // 3. Placeholder
    return _buildImagePlaceholder();
  }

  Widget _buildImagePlaceholder() {
    return Container(
      color: const Color(0xFFF1F5F9),
      child: const Center(
        child: Icon(Icons.image_outlined, color: AppTheme.textLightColor, size: 40),
      ),
    );
  }

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
            tooltip: 'Muat ulang produk',
          ),
        ],
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
                          onPressed: _loadProducts,
                          child: const Text('Coba Lagi')),
                    ],
                  ),
                )
              : _products.isEmpty
                  ? const Center(child: Text('Belum ada data produk.'))
                  : GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 220,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.75, // Proporsi Card Portrait
                      ),
                      itemCount: _products.length,
                      itemBuilder: (context, index) {
                        final product = _products[index];
                        final qty = _cart[product.id] ?? 0;

                        return Container(
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceColor,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () => _addToCart(product),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Bagian Gambar
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(8)),
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        _buildProductImage(product),
                                        if (qty > 0)
                                          Positioned(
                                            top: 8,
                                            right: 8,
                                            child: Container(
                                              padding: const EdgeInsets.all(6),
                                              decoration: const BoxDecoration(
                                                color: AppTheme.primaryColor,
                                                shape: BoxShape.circle,
                                              ),
                                              child: Text(
                                                '$qty',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                                // Bagian Teks
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
                                        'Rp ${formatCurrency.format(product.price)}',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: AppTheme.primaryColor,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
      bottomNavigationBar: _cart.isEmpty ? null : _buildBottomBar(formatCurrency),
    );
  }

  Widget _buildBottomBar(NumberFormat formatCurrency) {
    return GestureDetector(
      onTap: _showCartSheet,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: const BoxDecoration(
          color: AppTheme.surfaceColor,
          border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
        ),
        child: SafeArea(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$_totalItems Barang (ketuk untuk detail)',
                    style: const TextStyle(
                        color: AppTheme.textLightColor, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Rp ${formatCurrency.format(_totalPrice)}',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textColor,
                    ),
                  ),
                ],
              ),
              ElevatedButton(
                onPressed: _showCheckoutDialog,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 40, vertical: 16),
                ),
                child: const Text('BAYAR'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}