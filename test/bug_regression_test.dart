import 'package:flutter_test/flutter_test.dart';
import 'package:natunapos/core/file_utils.dart';
import 'package:natunapos/models/transaction.dart';

void main() {
  group('Bug #5 Regression: Cleanup Gambar Grace Period', () {
    test('Gambar baru (di bawah 10 menit) TIDAK BOLEH dihapus', () {
      final now = DateTime(2026, 1, 1, 10, 0, 0);
      final fileModified = DateTime(2026, 1, 1, 9, 55, 0); // 5 menit lalu
      
      final keep = FileUtils.shouldKeepOrphanedFile(
        now: now,
        fileModified: fileModified,
        isValidPath: false, // Tidak ada di database
      );
      
      expect(keep, true, reason: 'File baru harus dilindungi');
    });

    test('Gambar lama (di atas 10 menit) BOLEH dihapus', () {
      final now = DateTime(2026, 1, 1, 10, 0, 0);
      final fileModified = DateTime(2026, 1, 1, 9, 45, 0); // 15 menit lalu
      
      final keep = FileUtils.shouldKeepOrphanedFile(
        now: now,
        fileModified: fileModified,
        isValidPath: false, // Tidak ada di database
      );
      
      expect(keep, false, reason: 'File lama yang orphaned harus dihapus');
    });

    test('Gambar yang ada di database SELALU aman', () {
      final now = DateTime(2026, 1, 1, 10, 0, 0);
      final fileModified = DateTime(2026, 1, 1, 8, 0, 0); // 2 jam lalu
      
      final keep = FileUtils.shouldKeepOrphanedFile(
        now: now,
        fileModified: fileModified,
        isValidPath: true, // Ada di database
      );
      
      expect(keep, true, reason: 'File valid tidak boleh dihapus');
    });
  });

  group('Bug #3 Regression: Transaksi Void', () {
    test('Transaction.fromDb harus mengenali status void', () {
      final dbMap = {
        'id': -123,
        'total': 50000,
        'created_at': 1700000000000,
        'is_synced': 0,
        'is_voided': 1,
        'void_reason': 'Salah input',
        'voided_by': 'Kasir 1',
        'voided_at': 1700000005000,
      };

      final tx = Transaction.fromDb(dbMap, []);
      
      expect(tx.isVoided, true);
      expect(tx.voidReason, 'Salah input');
      expect(tx.voidedBy, 'Kasir 1');
      expect(tx.voidedAt, isNotNull);
    });
  });
}