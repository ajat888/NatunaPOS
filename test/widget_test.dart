import 'package:flutter_test/flutter_test.dart';
import 'package:natunapos/models/product.dart';
import 'package:natunapos/models/category.dart';

void main() {
  group('Product model', () {
    test('fromJson parses all fields', () {
      final p = Product.fromJson({
        'id': 1,
        'name': 'Kopi',
        'price': 10000,
        'hpp': 5000,
        'category_id': 2,
        'image_url': 'https://example.com/kopi.jpg',
      });
      expect(p.id, 1);
      expect(p.name, 'Kopi');
      expect(p.price, 10000);
      expect(p.hpp, 5000);
      expect(p.categoryId, 2);
      expect(p.imageUrl, 'https://example.com/kopi.jpg');
      expect(p.isSynced, true);
    });

    test('toDb produces valid map with is_synced flag', () {
      final p = Product(
        id: -1,
        name: 'Teh',
        price: 5000,
        hpp: 2000,
        categoryId: 3,
        isSynced: false,
      );
      final map = p.toDb();
      expect(map['id'], -1);
      expect(map['is_synced'], 0);
      expect(map['category_id'], 3);
    });

    test('fromDb parses correctly', () {
      final p = Product.fromDb({
        'id': 5,
        'name': 'Roti',
        'price': 8000,
        'hpp': 4000,
        'category_id': null,
        'image_url': null,
        'local_image_path': '/tmp/roti.jpg',
        'is_synced': 0,
      });
      expect(p.id, 5);
      expect(p.name, 'Roti');
      expect(p.isSynced, false);
      expect(p.localImagePath, '/tmp/roti.jpg');
    });
  });

  group('Category model', () {
    test('fromJson parses basic fields', () {
      final c = Category.fromJson({'id': 10, 'name': 'Minuman'});
      expect(c.id, 10);
      expect(c.name, 'Minuman');
      expect(c.isSynced, true);
    });

    test('toDb includes is_synced flag', () {
      final c = Category(id: -5, name: 'Snack', isSynced: false);
      final map = c.toDb();
      expect(map['id'], -5);
      expect(map['name'], 'Snack');
      expect(map['is_synced'], 0);
    });

    test('fromDb reads is_synced flag', () {
      final c = Category.fromDb({'id': 1, 'name': 'Makanan', 'is_synced': 0});
      expect(c.isSynced, false);
    });
  });
}