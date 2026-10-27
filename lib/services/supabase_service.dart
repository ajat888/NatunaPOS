import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/product.dart';
import '../models/category.dart';
import '../core/local_db.dart';

class SupabaseService {
  final SupabaseClient _client = Supabase.instance.client;
  final LocalDb _localDb = LocalDb.instance;
  bool _isSyncing = false;

  Future<AuthResponse> login(String email, String password) async {
    return await _client.auth.signInWithPassword(email: email, password: password);
  }
  Future<void> logout() async => await _client.auth.signOut();
  bool get isLoggedIn => _client.auth.currentSession != null;

  Future<List<Product>> getLocalProducts() => _localDb.getProducts();
  Future<List<Category>> getLocalCategories() => _localDb.getCategories();

  Future<void> syncData() async {
    if (_isSyncing) return;
    _isSyncing = true;
    
    try {
      final localCategories = await _localDb.getCategories();
      final unsyncedCategories = localCategories.where((c) => c.id < 0).toList();
      for (final c in unsyncedCategories) {
        try {
          final response = await _client.from('categories').insert({'name': c.name}).select().single();
          await _localDb.deleteCategory(c.id); 
          await _localDb.upsertCategory(Category.fromJson(response)); 
        } catch (_) {}
      }

      try {
        final response = await _client.from('categories').select().order('id', ascending: true);
        final serverCategories = (response as List).map((json) => Category.fromJson(json)).toList();
        await _localDb.replaceAllCategories(serverCategories);
      } catch (_) {}

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
            }).select().single();
            
            await _localDb.deleteProduct(p.id); 
            await _localDb.upsertProduct(Product.fromJson(response)); 
          } else {
            await _client.from('products').update({
              'name': p.name,
              'price': p.price,
              'hpp': p.hpp,
              'category_id': p.categoryId,
              'image_url': finalImageUrl,
            }).eq('id', p.id);
            
            await _localDb.upsertProduct(p.copyWith(isSynced: true));
          }
        } catch (_) {}
      }

      try {
        final response = await _client.from('products').select().order('id', ascending: true);
        final serverProducts = (response as List).map((json) => Product.fromJson(json)).toList();
        await _localDb.replaceAllProducts(serverProducts);
      } catch (_) {}
    } finally {
      _isSyncing = false;
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
    final tempId = -DateTime.now().millisecondsSinceEpoch;
    final p = Product(
      id: tempId, name: name, price: price, hpp: hpp,
      categoryId: categoryId, localImagePath: localImagePath, isSynced: false,
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
  }) async {
    final p = Product(
      id: id, name: name, price: price, hpp: hpp,
      categoryId: categoryId, imageUrl: existingImageUrl,
      localImagePath: localImagePath, isSynced: false,
    );
    await _localDb.upsertProduct(p);
  }

  Future<void> deleteProduct(int id) async {
    await _localDb.deleteProduct(id);
    if (id > 0) {
      Future(() async {
        try { await _client.from('products').delete().eq('id', id); } catch (_) {}
      });
    }
  }

  Future<void> createCategory(String name) async {
    final tempId = -DateTime.now().millisecondsSinceEpoch;
    await _localDb.upsertCategory(Category(id: tempId, name: name));
    Future(() async {
      try {
        final response = await _client.from('categories').insert({'name': name}).select().single();
        await _localDb.deleteCategory(tempId);
        await _localDb.upsertCategory(Category.fromJson(response));
      } catch (_) {}
    });
  }

  Future<void> updateCategory({required int id, required String name}) async {
    await _localDb.upsertCategory(Category(id: id, name: name));
    if (id > 0) {
      Future(() async {
        try { await _client.from('categories').update({'name': name}).eq('id', id); } catch (_) {}
      });
    }
  }

  Future<void> deleteCategory(int id) async {
    await _localDb.deleteCategory(id);
    if (id > 0) {
      Future(() async {
        try { await _client.from('categories').delete().eq('id', id); } catch (_) {}
      });
    }
  }
}