import 'package:flutter_test/flutter_test.dart';
import 'package:natunapos/models/product.dart';
import 'package:natunapos/models/transaction.dart';

void main() {
  group('Product Model', () {
    test('JSON to Model and Model to DB must be consistent', () {
      final json = {
        'id': 1,
        'name': 'Kopi Susu',
        'price': 15000,
        'hpp': 5000,
        'category_id': 2,
        'image_url': 'https://example.com/img.jpg',
        'is_active': true,
      };
      
      final product = Product.fromJson(json);
      expect(product.name, 'Kopi Susu');
      
      final dbMap = product.toDb();
      expect(dbMap['is_synced'], 1);
      expect(dbMap['is_deleted'], 0);
      
      final fromDb = Product.fromDb(dbMap);
      expect(fromDb.name, 'Kopi Susu');
      expect(fromDb.price, 15000);
    });
  });

  group('Transaction Model', () {
    test('Voided transaction should be parsed correctly from DB', () {
      final dbMap = {
        'id': 99,
        'total': 50000,
        'subtotal': 50000,
        'bill_discount': 0,
        'discount_type': 'nominal',
        'discount_value': 0,
        'tax_rate': 0.0,
        'tax_amount': 0,
        'created_at': 1700000000000,
        'is_synced': 1,
        'cash_received': 50000,
        'change_amount': 0,
        'is_voided': 1,
        'void_reason': 'Salah input',
        'voided_by': 'Kasir 1',
        'voided_at': 1700000005000,
      };

      final tx = Transaction.fromDb(dbMap, []);
      expect(tx.isVoided, true);
      expect(tx.voidReason, 'Salah input');
      expect(tx.voidedAt, isNotNull);
    });
  });
}