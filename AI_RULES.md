# AI Rules — NatunaPOS

**Dokumen ini otomatis dibaca setiap sesi. Patuhi seluruhnya tanpa kecuali.**

---

## 1. LINGKUNGAN KERJA

- User: HP Android. Acode (edit file) + Termux (git push SAJA).
- DILARANG menyuruh user jalankan `flutter pub get`, `flutter pub add`,
  `flutter build`, atau perintah berat lain di Termux.
- Butuh dependensi baru? Suruh edit `pubspec.yaml` manual via Acode.
  GitHub Actions yang mengunduh saat build.
- Saat mengeksekusi perubahan, JANGAN sentuh file di luar `lib/` kecuali
  benar-benar perlu (misal `.md`, `pubspec.yaml`).

## 2. FOLDER `android/`

- DILARANG sentuh (Gradle, AGP, Kotlin, Manifest, dsb) kecuali
  benar-benar mendesak (build error) dan sudah memperingatkan user.
- Jika terpaksa: sintaks 100% benar, jelaskan alasannya.

## 3. BATAS 500 BARIS

- File Dart maksimal 500 baris. Wajib split via `part`/`part of`.
- Jika membuat `part 'x.dart'`, WAJIB kirim file `x.dart` juga dengan
  `part of '...'` di respons yang sama.
- Jika `import 'y.dart'`, WAJIB pastikan file ada di repo atau buat di
  respons yang sama.
- Jangan memecah file < 300 baris hanya demi kerapian.

## 4. ARSITEKTUR: OFFLINE-FIRST

- Aplikasi HANYA membaca dari SQLite (`LocalDb`).
- DILARANG baca langsung dari Supabase sebelum menyimpan ke SQLite.
- Semua Tambah/Edit/Hapus: tulis ke SQLite dulu → UI update instan →
  sync ke Supabase di background.
- DILARANG bikin UI loading yang menunggu jaringan.
- ID lokal negatif → diganti ID server setelah sync.

## 5. 🔴 KONTRAK SINKRONISASI OTOMATIS (KRITIS — WAJIB)

Sinkronisasi sekarang ditangani secara **otomatis di dalam `LocalDb`**. 
Setiap method write di `LocalDb` (misal `upsertProduct`, `insertExpense`) memiliki parameter `bool skipSync = false`. Jika `skipSync` false, `LocalDb` akan otomatis memanggil `WriteNotifier.notify()`.

### Aturan Turunan

- **UI / Service Layer (SupabaseServiceData, ExpenseService)**: 
  DILARANG memanggil `WriteNotifier.notify()` secara manual. Cukup panggil method `LocalDb`, dan biarkan `LocalDb` yang memicu sync.
- **SyncRunner (Push/Pull)**: 
  Setiap pemanggilan method write ke `LocalDb` di dalam file `sync_runner_*.dart` WAJIB menyertakan argumen `skipSync: true`. Ini untuk mencegah *infinite loop* (karena sync tidak boleh memicu sync baru).
- **AppSettings**:
  Tetap menggunakan `AutoSyncScheduler.instance.scheduleSync()` di dalam `markDirty()` (pengecualian, karena bukan tabel SQLite).
- DILARANG memanggil `SupabaseService().syncData()` langsung dari UI. Hanya `AutoSyncScheduler` yang boleh.

### Checklist WAJIB Sebelum Jawab

- [ ] Jika mengubah/membuat method write di `LocalDb`: pastikan ada parameter `bool skipSync = false` dan panggil `if (!skipSync) await WriteNotifier.notify();` di akhir.
- [ ] Jika mengubah `SyncRunner` (Push/Pull): pastikan semua pemanggilan `LocalDb` memiliki `skipSync: true`.
- [ ] Jika mengubah UI/Service: pastikan TIDAK ADA pemanggilan `WriteNotifier.notify()` manual.
- [ ] Tidak ada `_service.syncData()` di luar `AutoSyncScheduler`.
- [ ] Tidak ada perubahan di folder `android/` (kecuali disepakati).
- [ ] Tidak ada `.withValues()` (Flutter 3.24 pakai `.withOpacity()`).
- [ ] Semua file `part`/`part of` dikirim lengkap.
- [ ] Tidak ada file > 500 baris.

## 6. DESAIN UI/UX

- Clean Banking: Navy/White, border tipis, radius 8, minim bayangan.
- Dilarang gradien norak / "AI slop".
- Navigasi: Drawer via `MainMenuScope.of(context)?.openMenu()`.
- Responsif wajib portrait + landscape:
  - Wajib pakai `Breakpoints.of(context)` (compact < 600, medium 600-900,
    expanded >= 900).
  - DILARANG `MediaQuery.sizeOf(context).width > N` ad-hoc.
- Dialog di-clamp lebarnya (contoh `screenW < 528 ? screenW - 88 : 400`).

## 7. BATASAN TEKNIS

- Flutter 3.24.0, Dart 3.5.0.
- DILARANG `.withValues()` — pakai `.withOpacity()`.
- DILARANG paket `syncable`, `drift`, atau yang butuh Dart >=3.6.
- Gambar: `path_provider` untuk simpan lokal.
- Orientasi: portrait + landscape, `SystemUiMode.manual` top+bottom.
- URL & keystore: via `--dart-define` (GitHub Secrets).

## 8. GAYA JAWABAN

1. Kode UTUH (1 file penuh) untuk setiap file yang diubah/dibuat.
2. Tanpa komentar dekoratif.
3. Jika ada split file, kirim SEMUA file (parent + part) dalam 1 jawaban.
4. Jelaskan singkat apa yang diubah.
5. Akhiri dengan tabel:
   | Path | Aksi | Baris |
   |---|---|---|
6. Beri perintah git push paling akhir (TANPA `cd`):
   `git add . && git commit -m "..." && git push origin main`

## 9. ALUR KERJA

- Jika permintaan ambigu atau menyentuh file banyak: KONFIRMASI dulu.
- Setelah konfirmasi, kirim semua file yang dibutuhkan sekaligus.
- Jangan tanya "mau saya lanjut?" di tengah jawaban — selesaikan.

## 10. 🔴 ATURAN ANTI-LUPA (JANGAN HAPUS FUNGSI YANG TIDAK BERKAITAN)

- Saat menulis ulang file (terutama UI atau file panjang), DILARANG KERAS menghapus atau memangkas fungsi, method, atau widget yang sudah ada sebelumnya kecuali diminta secara eksplisit oleh user.
- Jika tugasnya hanya memperbaiki 1 bug kecil, fokus HANYA pada bug tersebut. Jangan merombak kode yang tidak berkaitan.
- Jika AI merasa file terlalu panjang dan berisiko terpotong, AI WAJIB memecah file tersebut menjadi `part`/`part of` sebelum melakukan perbaikan.
- Ingat: Kehilangan 1 fungsi kecil (misal fungsi cetak struk atau validasi form) bisa merusak aplikasi secara keseluruhan.