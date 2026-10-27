import 'package:flutter/material.dart';
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        title: const Text('Konfirmasi Pembayaran'),
        content: Text(
            'Total tagihan: Rp $_totalPrice\n\nLanjutkan proses pembayaran?'),
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
                                      'Rp ${product.price} x ${entry.value}'),
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

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final availableWidth = screenWidth - 80;
    final crossAxisCount =
        availableWidth > 1100 ? 4 : (availableWidth > 700 ? 3 : 2);

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
                          style:
                              const TextStyle(color: AppTheme.dangerColor)),
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
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 2.5,
                      ),
                      itemCount: _products.length,
                      itemBuilder: (context, index) {
                        final product = _products[index];
                        final qty = _cart[product.id] ?? 0;
                        return Container(
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceColor,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: const Color(0xFFE2E8F0)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment:
                                        MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        product.name,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.textColor,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Rp ${product.price}',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: AppTheme.textLightColor,
                                        ),
                                      ),
                                      if (qty > 0)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(top: 4),
                                          child: Text(
                                            'Dalam keranjang: $qty',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: AppTheme.primaryColor,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => _addToCart(product),
                                  style: IconButton.styleFrom(
                                    backgroundColor: AppTheme.primaryColor
                                        .withOpacity(0.1),
                                    foregroundColor: AppTheme.primaryColor,
                                  ),
                                  icon: const Icon(Icons.add),
                                )
                              ],
                            ),
                          ),
                        );
                      },
                    ),
      bottomNavigationBar: _cart.isEmpty ? null : _buildBottomBar(),
    );
  }

  Widget _buildBottomBar() {
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
                    'Rp $_totalPrice',
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