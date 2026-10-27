import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/product.dart';
import '../models/category.dart';
import '../core/local_db.dart';

class SupabaseService {
  final SupabaseClient _client = Supabase.instance.client;
  final LocalDb _localDb = LocalDb.instance;

  // === AUTH ===
  Future<AuthResponse> login(String email, String password) async {
    return await _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> logout() async => await _client.auth.signOut();
  bool get isLoggedIn => _client.auth.currentSession != null;

  // === STORAGE ===
  Future<String> uploadProductImage(File file) async {
    try {
      final fileName = 'product_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await _client.storage.from('product_images').upload(fileName, file);
      return _client.storage.from('product_images').getPublicUrl(fileName);
    } catch (e) {
      throw Exception('Gagal mengunggah gambar: $e');
    }
  }

  // === PRODUCTS ===
  Future<List<Product>> fetchProducts() async {
    try {
      final response = await _client.from('products').select().order('id', ascending: true);
      final products = (response as List).map((json) => Product.fromJson(json)).toList();
      await _localDb.replaceAllProducts(products);
      return products;
    } catch (e) {
      final localProducts = await _localDb.getProducts();
      if (localProducts.isEmpty) throw Exception('Tidak ada koneksi internet dan data lokal kosong.');
      return localProducts;
    }
  }

  Future<Product> createProduct({
    required String name,
    required int price,
    required int hpp,
    int? categoryId,
    String? imageUrl,
  }) async {
    try {
      final response = await _client.from('products').insert({
        'name': name,
        'price': price,
        'hpp': hpp,
        'category_id': categoryId,
        'image_url': imageUrl,
      }).select().single();
      final created = Product.fromJson(response);
      await _localDb.upsertProduct(created);
      return created;
    } on PostgrestException catch (e) {
      throw Exception('Gagal menambah produk: ${e.message}');
    } catch (e) {
      throw Exception('Gagal menambah produk. Pastikan Anda terhubung ke internet.');
    }
  }

  Future<Product> updateProduct({
    required int id,
    required String name,
    required int price,
    required int hpp,
    int? categoryId,
    String? imageUrl,
  }) async {
    try {
      final response = await _client.from('products').update({
        'name': name,
        'price': price,
        'hpp': hpp,
        'category_id': categoryId,
        'image_url': imageUrl,
      }).eq('id', id).select().single();
      final updated = Product.fromJson(response);
      await _localDb.upsertProduct(updated);
      return updated;
    } on PostgrestException catch (e) {
      throw Exception('Gagal memperbarui produk: ${e.message}');
    } catch (e) {
      throw Exception('Gagal memperbarui produk. Pastikan Anda terhubung ke internet.');
    }
  }

  Future<void> deleteProduct(int id) async {
    try {
      await _client.from('products').delete().eq('id', id);
      await _localDb.deleteProduct(id);
    } on PostgrestException catch (e) {
      throw Exception('Gagal menghapus produk: ${e.message}');
    } catch (e) {
      throw Exception('Gagal menghapus produk. Pastikan Anda terhubung ke internet.');
    }
  }

  // === CATEGORIES ===
  Future<List<Category>> fetchCategories() async {
    try {
      final response = await _client.from('categories').select().order('id', ascending: true);
      final categories = (response as List).map((json) => Category.fromJson(json)).toList();
      await _localDb.replaceAllCategories(categories);
      return categories;
    } catch (e) {
      return await _localDb.getCategories();
    }
  }

  Future<Category> createCategory(String name) async {
    try {
      final response = await _client.from('categories').insert({'name': name}).select().single();
      final created = Category.fromJson(response);
      await _localDb.upsertCategory(created);
      return created;
    } on PostgrestException catch (e) {
      throw Exception('Gagal menambah kategori: ${e.message}');
    } catch (e) {
      throw Exception('Gagal menambah kategori. Pastikan Anda terhubung ke internet.');
    }
  }

  Future<Category> updateCategory({required int id, required String name}) async {
    try {
      final response = await _client.from('categories').update({'name': name}).eq('id', id).select().single();
      final updated = Category.fromJson(response);
      await _localDb.upsertCategory(updated);
      return updated;
    } on PostgrestException catch (e) {
      throw Exception('Gagal memperbarui kategori: ${e.message}');
    } catch (e) {
      throw Exception('Gagal memperbarui kategori. Pastikan Anda terhubung ke internet.');
    }
  }

  Future<void> deleteCategory(int id) async {
    try {
      await _client.from('categories').delete().eq('id', id);
      await _localDb.deleteCategory(id);
    } on PostgrestException catch (e) {
      throw Exception('Gagal menghapus kategori: ${e.message}');
    } catch (e) {
      throw Exception('Gagal menghapus kategori. Pastikan Anda terhubung ke internet.');
    }
  }
}