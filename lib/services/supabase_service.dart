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

  // === SYNC LOGIC (OFFLINE TO ONLINE) ===
  Future<void> syncLocalData() async {
    try {
      // 1. Ambil data yang belum sinkron dari lokal
      final unsynced = await _localDb.getUnsyncedProducts();
      if (unsynced.isEmpty) return;

      // 2. Loop dan upload satu per satu
      for (final product in unsynced) {
        String? finalImageUrl = product.imageUrl;

        // Upload gambar lokal ke Supabase jika ada
        if (product.localImagePath != null && File(product.localImagePath!).existsSync()) {
          final file = File(product.localImagePath!);
          finalImageUrl = await uploadProductImage(file);
        }

        // Insert ke Supabase (tanpa ID, biarkan Supabase generate)
        final response = await _client.from('products').insert({
          'name': product.name,
          'price': product.price,
          'hpp': product.hpp,
          'category_id': product.categoryId,
          'image_url': finalImageUrl,
        }).select().single();

        final syncedProduct = Product.fromJson(response);

        // Hapus data lokal yang ID-nya negatif (sementara)
        await _localDb.deleteProduct(product.id);
        
        // Simpan data baru yang sudah punya ID dari Supabase
        await _localDb.upsertProduct(syncedProduct);
      }
    } catch (e) {
      // Abaikan error, akan dicoba lagi di kesempatan berikutnya
    }
  }

  Future<String> uploadProductImage(File file) async {
    final fileName = 'product_${DateTime.now().millisecondsSinceEpoch}.jpg';
    await _client.storage.from('product_images').upload(fileName, file);
    return _client.storage.from('product_images').getPublicUrl(fileName);
  }

  // === PRODUCTS ===
  Future<List<Product>> fetchProducts() async {
    try {
      // Panggil sinkronisasi dulu sebelum tarik data terbaru
      await syncLocalData();

      final response = await _client.from('products').select().order('id', ascending: true);
      final products = (response as List).map((json) => Product.fromJson(json)).toList();
      await _localDb.replaceAllProducts(products);
      return await _localDb.getProducts(); // Kembalikan gabungan server + lokal yang belum sync
    } catch (e) {
      final localProducts = await _localDb.getProducts();
      if (localProducts.isEmpty) throw Exception('Tidak ada koneksi internet dan data lokal kosong.');
      return localProducts;
    }
  }

  Future<void> createProduct({
    required String name,
    required int price,
    required int hpp,
    int? categoryId,
    File? localImageFile,
    String? localImagePath,
  }) async {
    try {
      // Coba Online
      String? finalImageUrl;
      if (localImageFile != null) {
        finalImageUrl = await uploadProductImage(localImageFile);
      }
      final response = await _client.from('products').insert({
        'name': name,
        'price': price,
        'hpp': hpp,
        'category_id': categoryId,
        'image_url': finalImageUrl,
      }).select().single();
      
      final created = Product.fromJson(response);
      await _localDb.upsertProduct(created);
    } catch (e) {
      // Gagal (Offline): Simpan ke lokal dengan ID Negatif
      final tempId = -DateTime.now().millisecondsSinceEpoch;
      final offlineProduct = Product(
        id: tempId,
        name: name,
        price: price,
        hpp: hpp,
        categoryId: categoryId,
        imageUrl: null,
        localImagePath: localImagePath,
        isSynced: false,
      );
      await _localDb.upsertProduct(offlineProduct);
      // Tidak throw error, biarkan UI merasa sukses (mode offline)
    }
  }

  Future<void> updateProduct({
    required int id,
    required String name,
    required int price,
    required int hpp,
    int? categoryId,
    File? localImageFile,
    String? localImagePath,
    String? existingImageUrl,
  }) async {
    try {
      // Coba Online
      String? finalImageUrl = existingImageUrl;
      if (localImageFile != null) {
        finalImageUrl = await uploadProductImage(localImageFile);
      }
      
      final response = await _client.from('products').update({
        'name': name,
        'price': price,
        'hpp': hpp,
        'category_id': categoryId,
        'image_url': finalImageUrl,
      }).eq('id', id).select().single();
      
      final updated = Product.fromJson(response);
      await _localDb.upsertProduct(updated);
    } catch (e) {
      // Gagal (Offline): Update lokal
      final offlineProduct = Product(
        id: id,
        name: name,
        price: price,
        hpp: hpp,
        categoryId: categoryId,
        imageUrl: existingImageUrl,
        localImagePath: localImagePath,
        isSynced: false,
      );
      await _localDb.upsertProduct(offlineProduct);
    }
  }

  Future<void> deleteProduct(int id) async {
    try {
      if (id > 0) {
        await _client.from('products').delete().eq('id', id);
      }
      await _localDb.deleteProduct(id);
    } catch (e) {
      // Jika offline, setidaknya hapus dari lokal
      await _localDb.deleteProduct(id);
      throw Exception('Produk dihapus lokal. Server akan disinkronkan nanti.');
    }
  }

  // === CATEGORIES ===
  // (Sama seperti sebelumnya, kategori tidak butuh gambar)
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

  Future<void> createCategory(String name) async {
    try {
      final response = await _client.from('categories').insert({'name': name}).select().single();
      await _localDb.upsertCategory(Category.fromJson(response));
    } catch (e) {
      throw Exception('Gagal menambah kategori. Diperlukan internet untuk fitur ini.');
    }
  }

  Future<void> updateCategory({required int id, required String name}) async {
    try {
      final response = await _client.from('categories').update({'name': name}).eq('id', id).select().single();
      await _localDb.upsertCategory(Category.fromJson(response));
    } catch (e) {
      throw Exception('Gagal memperbarui kategori. Diperlukan internet untuk fitur ini.');
    }
  }

  Future<void> deleteCategory(int id) async {
    try {
      await _client.from('categories').delete().eq('id', id);
      await _localDb.deleteCategory(id);
    } catch (e) {
      throw Exception('Gagal menghapus kategori. Diperlukan internet untuk fitur ini.');
    }
  }
}