import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/product.dart';
import '../core/local_db.dart'; // Import LocalDb

class SupabaseService {
  final SupabaseClient _client = Supabase.instance.client;
  final LocalDb _localDb = LocalDb.instance; // Inisialisasi LocalDb

  // === AUTH ===
  Future<AuthResponse> login(String email, String password) async {
    return await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<void> logout() async {
    await _client.auth.signOut();
  }

  bool get isLoggedIn => _client.auth.currentSession != null;

  // === DATABASE ===
  Future<List<Product>> fetchProducts() async {
    try {
      // 1. Coba ambil data terbaru dari Supabase
      final response = await _client
          .from('products')
          .select()
          .order('id', ascending: true);
      
      final products = (response as List).map((json) => Product.fromJson(json)).toList();
      
      // 2. Jika berhasil, simpan ke database HP (Cache)
      await _localDb.saveProducts(products);
      
      return products;

    } catch (e) {
      // 3. Jika gagal (internet mati), ambil dari database HP
      final localProducts = await _localDb.getProducts();
      
      if (localProducts.isEmpty) {
        // Jika HP juga belum punya data sama sekali, lempar error
        throw Exception('Tidak ada koneksi internet dan data lokal kosong.');
      }
      
      return localProducts;
    }
  }
}