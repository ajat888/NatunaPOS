import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../models/product.dart';
import '../core/theme.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _service = SupabaseService();
  List<Product> _products = [];
  final Map<Product, int> _cart = {};
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    try {
      final products = await _service.fetchProducts();
      if (!mounted) return;
      setState(() {
        _products = products;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Gagal memuat produk. Periksa koneksi internet.';
      });
    }
  }

  void _addToCart(Product product) {
    setState(() {
      if (_cart.containsKey(product)) {
        _cart[product] = _cart[product]! + 1;
      } else {
        _cart[product] = 1;
      }
    });
  }

  int get _totalPrice {
    int total = 0;
    _cart.forEach((product, qty) => total += product.price * qty);
    return total;
  }

  int get _totalItems {
    int total = 0;
    _cart.forEach((_, qty) => total += qty);
    return total;
  }

  Future<void> _handleLogout() async {
    await _service.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  void _showCheckoutDialog() {
    if (_cart.isEmpty) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Konfirmasi Pembayaran'),
        content: Text('Total tagihan: Rp $_totalPrice\n\nLanjutkan proses pembayaran?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('BATAL', style: TextStyle(color: AppTheme.textLightColor)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => _cart.clear());
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Transaksi Berhasil!'), backgroundColor: Colors.green),
              );
            },
            child: const Text('BAYAR'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Deteksi lebar layar untuk menentukan jumlah kolom grid
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = screenWidth > 1200 ? 4 : (screenWidth > 800 ? 3 : 2);

    return Scaffold(
      appBar: AppBar(
        title: const Text('NatunaPOS'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: AppTheme.textLightColor),
            onPressed: _handleLogout,
            tooltip: 'Keluar',
          ),
          const SizedBox(width: 8),
        ],
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
                      TextButton(onPressed: _loadProducts, child: const Text('Coba Lagi')),
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
                        childAspectRatio: 2.5, // Menjaga kotak tetap proporsional
                      ),
                      itemCount: _products.length,
                      itemBuilder: (context, index) {
                        final product = _products[index];
                        return Container(
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
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
                                    ],
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => _addToCart(product),
                                  style: IconButton.styleFrom(
                                    backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
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
    return Container(
      padding: const EdgeInsets.all(20),
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
                  '$_totalItems Barang',
                  style: const TextStyle(color: AppTheme.textLightColor, fontSize: 13),
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
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
              child: const Text('BAYAR'),
            ),
          ],
        ),
      ),
    );
  }
}