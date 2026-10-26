import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/product.dart';

class SupabaseService {
  final SupabaseClient _client = Supabase.instance.client;

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
    final response = await _client
        .from('products')
        .select()
        .order('id', ascending: true);
    
    return (response as List).map((json) => Product.fromJson(json)).toList();
  }
}