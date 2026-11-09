// lib/core/file_utils.dart
class FileUtils {
  FileUtils._();

  /// Mengembalikan true jika file harus DIPERTAHANKAN.
  /// Mengembalikan false jika file BOLEH DIHAPUS.
  static bool shouldKeepOrphanedFile({
    required DateTime now,
    required DateTime fileModified,
    required bool isValidPath,
  }) {
    // 1. Jika file terdaftar di database (valid), jangan pernah hapus.
    if (isValidPath) return true;

    // 2. Jika umur file kurang dari 10 menit, lindungi (Grace Period).
    if (now.difference(fileModified) < const Duration(minutes: 10)) {
      return true;
    }

    // 3. Jika orphaned DAN sudah lebih dari 10 menit, izinkan dihapus.
    return false;
  }
}