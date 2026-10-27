import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/product.dart';
import '../models/category.dart';
import '../core/local_db.dart';

class SupabaseService {
  final SupabaseClient _client = Supabase.instance.client;
  final LocalDb _localDb = LocalDb.instance;
  bool _isSyncing = false;

  // === AUTH ===
  Future<AuthResponse> login(String email, String password) async {
    return await _client.auth.signInWithPassword(email: email, password: password);
  }
  Future<void> logout() async => await _client.auth.signOut();
  bool get isLoggedIn => _client.auth.currentSession != null;

  // === LOCAL READS ===
  Future<List<Product>> getLocalProducts() => _localDb.getProducts();
  Future<List<Category>> getLocalCategories() => _localDb.getCategories();

  // === VALIDATION ===
  Future<bool> isProductNameExists(String name, {int? excludeId}) async {
    final products = await _localDb.getProducts();
    return products.any((p) => p.name.toLowerCase() == name.toLowerCase() && p.id != excludeId);
  }

  Future<bool> isCategoryNameExists(String name, {int? excludeId}) async {
    final categories = await _localDb.getCategories();
    return categories.any((c) => c.name.toLowerCase() == name.toLowerCase() && c.id != excludeId);
  }

  // === BACKGROUND SYNC ===
  Future<void> syncData() async {
    if (_isSyncing) return;
    _isSyncing = true;
    
    try {
      // 1. Upload Kategori Baru (Offline)
      final localCategories = await _localDb.getCategories();
      final unsyncedCategories = localCategories.where((c) => c.id < 0).toList();
      for (final c in unsyncedCategories) {
        try {
          final response = await _client.from('categories').insert({
            'name': c.name,
            'is_active': c.isActive,
          }).select().single();
          
          // PERBAIKAN BUG: Hapus ID negatif dari HP
          await _localDb.hardDeleteCategory(c.id); 
          await _localDb.upsertCategory(Category.fromJson(response)); 
        } catch (_) {}
      }

      // Tarik Kategori dari Server
      try {
        final response = await _client.from('categories').select().order('id', ascending: true);
        final serverCategories = (response as List).map((json) => Category.fromJson(json)).toList();
        await _localDb.replaceAllCategories(serverCategories);
      } catch (_) {}

      // 2. Upload Produk Baru/Edit (Offline)
      final unsyncedProducts = await _localDb.getUnsyncedProducts();
      for (final p in unsyncedProducts) {
        try {
          String? finalImageUrl = p.imageUrl;
          if (p.localImagePath != null && File(p.localImagePath!).existsSync()) {
            final fileName = 'product_${DateTime.now().millisecondsSinceEpoch}.jpg';
            await _client.storage.from('product_images').upload(fileName, File(p.localImagePath!));
            finalImageUrl = _client.storage.from('product_images').getPublicUrl(fileName);
          }

          if (p.id < 0) {
            final response = await _client.from('products').insert({
              'name': p.name,
              'price': p.price,
              'hpp': p.hpp,
              'category_id': p.categoryId,
              'image_url': finalImageUrl,
              'is_active': p.isActive,
            }).select().single();
            
            await _localDb.hardDeleteProduct(p.id); // Hapus ID negatif
            await _localDb.upsertProduct(Product.fromJson(response)); 
          } else {
            await _client.from('products').update({
              'name': p.name,
              'price': p.price,
              'hpp': p.hpp,
              'category_id': p.categoryId,
              'image_url': finalImageUrl,
              'is_active': p.isActive,
            }).eq('id', p.id);
            
            await _localDb.upsertProduct(p.copyWith(isSynced: true));
          }
        } catch (_) {}
      }

      // Tarik Produk
      try {
        final response = await _client.from('products').select().order('id', ascending: true);
        final serverProducts = (response as List).map((json) => Product.fromJson(json)).toList();
        await _localDb.replaceAllProducts(serverProducts);
      } catch (_) {}

      // 3. Sinkronisasi Soft Delete Kategori
      final allLocalCat = await _localDb.getCategories();
      final inactiveCats = allLocalCat.where((c) => c.id > 0 && !c.isActive).toList();
      for (final c in inactiveCats) {
        try {
          await _client.from('categories').update({'is_active': false}).eq('id', c.id);
        } catch (_) {}
      }

    } finally {
      _isSyncing = false;
    }
  }

  // === CRUD PRODUCTS ===
  Future<void> createProduct({
    required String name,
    required int price,
    required int hpp,
    int? categoryId,
    File? localImageFile,
    String? localImagePath,
  }) async {
    if (await isProductNameExists(name)) {
      throw Exception('Nama produk sudah ada. Gunakan nama lain.');
    }
    final tempId = -DateTime.now().millisecondsSinceEpoch;
    final p = Product(
      id: tempId,
      name: name,
      price: price,
      hpp: hpp,
      categoryId: categoryId,
      localImagePath: localImagePath,
      isSynced: false,
      isActive: true,
    );
    await _localDb.upsertProduct(p);
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
    required bool isActive,
  }) async {
    if (await isProductNameExists(name, excludeId: id)) {
      throw Exception('Nama produk sudah ada. Gunakan nama lain.');
    }
    final p = Product(
      id: id,
      name: name,
      price: price,
      hpp: hpp,
      categoryId: categoryId,
      imageUrl: existingImageUrl,
      localImagePath: localImagePath,
      isSynced: false,
      isActive: isActive,
    );
    await _localDb.upsertProduct(p);
  }

  Future<void> deleteProduct(int id) async {
    await _localDb.softDeleteProduct(id);
    Future(() async {
      if (id > 0) {
        try { await _client.from('products').update({'is_active': false}).eq('id', id); } catch (_) {}
      }
    });
  }

  // === CRUD CATEGORIES ===
  Future<void> createCategory(String name) async {
    if (await isCategoryNameExists(name)) {
      throw Exception('Nama kategori sudah ada. Gunakan nama lain.');
    }
    final tempId = -DateTime.now().millisecondsSinceEpoch;
    await _localDb.upsertCategory(Category(id: tempId, name: name, isActive: true));
    Future(() async {
      try {
        final response = await _client.from('categories').insert({'name': name, 'is_active': true}).select().single();
        await _localDb.hardDeleteCategory(tempId);
        await _localDb.upsertCategory(Category.fromJson(response));
      } catch (_) {}
    });
  }

  Future<void> updateCategory({required int id, required String name, required bool isActive}) async {
    if (await isCategoryNameExists(name, excludeId: id)) {
      throw Exception('Nama kategori sudah ada. Gunakan nama lain.');
    }
    await _localDb.upsertCategory(Category(id: id, name: name, isActive: isActive));
    Future(() async {
      if (id > 0) {
        try { await _client.from('categories').update({'name': name, 'is_active': isActive}).eq('id', id); } catch (_) {}
      }
    });
  }

  Future<void> deleteCategory(int id) async {
    await _localDb.softDeleteCategory(id);
    Future(() async {
      if (id > 0) {
        try {
          await _client.from('categories').update({'is_active': false}).eq('id', id);
          await _client.from('products').update({'is_active': false}).eq('category_id', id);
        } catch (_) {}
      }
    });
  }
}