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

Setiap operasi write yang di-trigger dari UI (tambah/edit/hapus produk,
kategori, transaksi, bayar, void, pengeluaran, pengaturan) WAJIB
memanggil:

```dart
await WriteNotifier.notify();
```

setelah write ke SQLite berhasil.

Aturan Turunan

· Lokasi yang WAJIB memanggil WriteNotifier.notify() di akhir:
  · lib/services/supabase_service_data.dart (semua method write)
  · lib/services/expense_service.dart (semua method write)
  · lib/screens/pos_screen.dart (setelah simpan open order / ubah qty)
  · lib/services/app_settings.dart::markDirty (sudah handle via scheduleSync internal — JANGAN diubah)
· WriteNotifier.notify() melakukan:
  1. refreshPendingCount() → update badge
  2. scheduleSync() → debounce 1.5 detik trigger sync background
· DILARANG memanggil SupabaseService().syncData() langsung dari UI.
  Hanya AutoSyncScheduler yang boleh.
· LocalDb dan SyncRunner JANGAN diubah untuk menambah trigger sync —
  menyebabkan infinite loop.

Checklist WAJIB Sebelum Jawab

☐ Setiap method write baru di service layer memanggil WriteNotifier.notify()
☐ Grep refreshPendingCount() + scheduleSync() di file yang diubah —
  pastikan pasangan ini sudah diganti WriteNotifier.notify()
☐ Tidak ada _service.syncData() di luar AutoSyncScheduler
☐ Tidak ada perubahan di folder android/ (kecuali disepakati)
☐ Tidak ada .withValues() (Flutter 3.24 pakai .withOpacity())
☐ Semua file part/part of dikirim lengkap
☐ Tidak ada file > 500 baris

6. DESAIN UI/UX

· Clean Banking: Navy/White, border tipis, radius 8, minim bayangan.
· Dilarang gradien norak / "AI slop".
· Navigasi: Drawer via MainMenuScope.of(context)?.openMenu().
· Responsif wajib portrait + landscape:
  · Wajib pakai Breakpoints.of(context) (compact < 600, medium 600-900,
    expanded >= 900).
  · DILARANG MediaQuery.sizeOf(context).width > N ad-hoc.
· Dialog di-clamp lebarnya (contoh screenW < 528 ? screenW - 88 : 400).

7. BATASAN TEKNIS

· Flutter 3.24.0, Dart 3.5.0.
· DILARANG .withValues() — pakai .withOpacity().
· DILARANG paket syncable, drift, atau yang butuh Dart >=3.6.
· Gambar: path_provider untuk simpan lokal.
· Orientasi: portrait + landscape, SystemUiMode.manual top+bottom.
· URL & keystore: via --dart-define (GitHub Secrets).

8. GAYA JAWABAN

1. Kode UTUH (1 file penuh) untuk setiap file yang diubah/dibuat.
2. Tanpa komentar dekoratif.
3. Jika ada split file, kirim SEMUA file (parent + part) dalam 1 jawaban.
4. Jelaskan singkat apa yang diubah.
5. Akhiri dengan tabel:
   Path Aksi Baris
6. Beri perintah git push paling akhir (TANPA cd):
   git add . && git commit -m "..." && git push origin main

9. ALUR KERJA

· Jika permintaan ambigu atau menyentuh file banyak: KONFIRMASI dulu.
· Setelah konfirmasi, kirim semua file yang dibutuhkan sekaligus.
· Jangan tanya "mau saya lanjut?" di tengah jawaban — selesaikan.

```
