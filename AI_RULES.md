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
  benar-benar perlu (misal `.md`, `pubspec.yaml`, `.yaml`).

## 2. FOLDER `android/`

- DILARANG sentuh (Gradle, AGP, Kotlin, Manifest, dsb) kecuali
  benar-benar mendesak (build error) dan sudah memperingatkan user.
- Jika terpaksa: sintaks 100% benar, jelaskan alasannya.

## 3. BATAS 500 BARIS & LINTER

- File Dart maksimal 500 baris. Wajib split via `part`/`part of`.
- Jika membuat `part 'x.dart'`, WAJIB kirim file `x.dart` juga dengan
  `part of '...'` di respons yang sama.
- Jika `import 'y.dart'`, WAJIB pastikan file ada di repo atau buat di
  respons yang sama.
- **WAJIB BERSIH DARI LINTER:** Dilarang meninggalkan `unused_import`, 
  `unused_local_variable`, `unused_field`, `unnecessary_cast`, atau 
  `unnecessary_null_comparison`. Pastikan kode lulus `flutter analyze`.
- Detail lengkap aturan linter (5 error analyzer + 7 linter tambahan)
  ada di **§13**. Jika §3 dan §13 berbeda, §13 yang menang (dan §13
  tunduk pada `analysis_options.yaml`).

## 4. ARSITEKTUR: OFFLINE-FIRST

- Aplikasi HANYA membaca dari SQLite (`LocalDb`).
- DILARANG baca langsung dari Supabase sebelum menyimpan ke SQLite.
- Semua Tambah/Edit/Hapus: tulis ke SQLite dulu → UI update instan →
  sync ke Supabase di background.
- DILARANG bikin UI loading yang menunggu jaringan.
- ID lokal negatif → diganti ID server setelah sync.

## 5. 🔴 KONTRAK SINKRONISASI OTOMATIS (KRITIS — WAJIB)

Sinkronisasi ditangani secara **otomatis di dalam `LocalDb`**. 
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
- [ ] Tidak ada kode yang memicu error linter (unused import, dll).

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

1. **Aturan Pengiriman Kode:**
   - **Surgical Edit (Wajib untuk perubahan kecil):** Jika perubahan hanya 1-2 fungsi, method, atau widget, KIRIM HANYA BLOK YANG BERUBAH. DILARANG mengirim ulang file utuh.
   - **File Utuh:** Hanya dikirim jika file tersebut baru dibuat, atau dirombak total (>50% baris berubah).
2. **ZERO COMMENT POLICY:** Dilarang menyertakan komentar apapun di dalam blok kode (`//`, `/* */`, atau `///`), baik untuk *Surgical Edit* maupun *File Utuh*. Kode harus murni berisi *syntax*.
3. Jika ada split file, kirim SEMUA file (parent + part) dalam 1 jawaban.
4. Jelaskan singkat apa yang diubah.
5. Akhiri dengan tabel:
   | Path | Aksi | Baris |
   |---|---|---|
6. Beri perintah git push paling akhir (TANPA `cd`):
   `git add . && git commit -m "..." && git push origin main`

## 9. ALUR KERJA & UNIT TEST

- Jika permintaan ambigu atau menyentuh file banyak: KONFIRMASI dulu.
- Setelah konfirmasi, kirim semua file yang dibutuhkan sekaligus.
- Jangan tanya "mau saya lanjut?" di tengah jawaban — selesaikan.
- **PEMBARUAN TEST:** Jika AI mengubah model data (di folder `lib/models`), WAJIB memastikan file unit test (di folder `test/`) tidak error dan ikut diperbarui jika perlu.

## 10. 🔴 ATURAN ANTI-LUPA (JANGAN HAPUS FUNGSI YANG TIDAK BERKAITAN)

- Saat menulis ulang file (terutama UI atau file panjang), DILARANG KERAS menghapus atau memangkas fungsi, method, atau widget yang sudah ada sebelumnya kecuali diminta secara eksplisit oleh user.
- Jika tugasnya hanya memperbaiki 1 bug kecil, fokus HANYA pada bug tersebut. Jangan merombak kode yang tidak berkaitan.
- Jika AI merasa file terlalu panjang dan berisiko terpotong, AI WAJIB memecah file tersebut menjadi `part`/`part of` sebelum melakukan perbaikan.
- Ingat: Kehilangan 1 fungsi kecil (misal fungsi cetak struk atau validasi form) bisa merusak aplikasi secara keseluruhan.

## 11. 🔄 ATURAN PEMBARUAN `AI_RULES.md` (META-RULE)

- AI **HANYA BOLEH** mengupdate `AI_RULES.md` jika user secara eksplisit memerintahkan, ATAU jika ada perubahan arsitektur fundamental (misal: ganti database, ubah pola sinkronisasi, dsb).
- AI **DILARANG** mengupdate `AI_RULES.md` untuk perubahan kecil (tambah UI, fix bug, ganti teks).
- Jika mengupdate, AI **WAJIB** memberikan isi file `AI_RULES.md` secara **UTUH (full file)**. DILARANG memberikan instruksi seperti "tambahkan di baris sekian" atau memberikan potongan kode (snippet) saja. User akan melakukan copy-paste seluruh file.

## 12. 🧭 MODE PENASIATIF STRATEGIS (KONDISIONAL)

### 12.1 Kapan Aktif

Aktif **HANYA** ketika user meminta salah satu dari:
- Saran, rekomendasi, atau pendapat.
- Rencana, roadmap, atau strategi.
- Review arah proyek / keputusan arsitektur tingkat tinggi.
- Estimasi biaya, waktu, risiko, atau kelayakan.
- Solusi/protokol/prompt yang akan dipakai di sesi lain (bukan
  dieksekusi di chat yang sedang berjalan).

**Tidak aktif** untuk permintaan eksekusi kode biasa (fix bug, tambah
widget, split file, refactor mekanis). Untuk itu berlaku §8 murni tanpa
nada penasihat.

### 12.2 Klausa Non-Override (WAJIB)

§2, §3, §5, §7, §10, dan **§13** bersifat **non-negotiable**. "Realisme" TIDAK
boleh dipakai sebagai alasan untuk:
- Menyentuh `android/` tanpa peringatan.
- Melanggar kontrak `skipSync` / `WriteNotifier`.
- Memakai `.withValues()` atau paket terlarang.
- Menghapus fungsi yang tidak berkaitan.
- Melanggar aturan linter.

Jika realita menuntut pelanggaran aturan keras, AI **WAJIB** menyatakan
konfliknya secara eksplisit di "Kenyataan yang Tidak Nyaman" — bukan
melanggarnya diam-diam.

### 12.3 Nada & Prinsip

- Anggap user memiliki bias. Optimalkan untuk **kebenaran dan realisme**,
  bukan kenyamanan user.
- Cari asumsi keliru, risiko tersembunyi, dan **urgensi palsu**.
- Jika rencana bergantung pada keberuntungan atau "cari jalan sambil
  jalan", sebutkan secara eksplisit.
- Terjemahkan gagasan abstrak menjadi **biaya, waktu, dan probabilitas
  kegagalan** yang konkret.
- Jika tidak ada opsi yang baik, katakan dengan jelas.
- Definisikan istilah khusus secara singkat saat pertama muncul.

### 12.4 Format Respons (WAJIB, urutan persis)

1. **Kenyataan yang Tidak Nyaman** — nyatakan kenyataan pahit dulu.
2. **Kelemahan** — mengapa pemikiran user saat ini tidak memadai.
3. **Batasan** — batasan dunia nyata yang diabaikan user.
4. **Langkah ke Depan** — jalan bertindak paling tidak delusif.
5. **Hal yang Harus Dihentikan** — spesifik apa yang harus berhenti.
6. **Aturan** — pagar untuk mencegah tindakan bodoh berikutnya.

### 12.5 Integrasi dengan §8

- Untuk pertanyaan yang **murni strategis** (tanpa perubahan file):
  hanya §12.4 yang berlaku. Tidak perlu tabel Path/Aksi/Baris maupun
  perintah `git push`. Deliverable-nya adalah **artefak siap-bawa**
  (dokumen, prompt, checklist, protokol) yang akan dipakai di sesi
  lain. Artefak tersebut harus mandiri — tidak boleh bergantung pada
  konteks chat ini.
- Untuk pertanyaan yang **menghasilkan perubahan file** (misal "review
  arsitektur sync lalu perbaiki"): §12.4 **menggantikan** §8 ayat 1–4
  (narasi singkat), tetapi deliverable §8 ayat 5–6 (tabel
  `| Path | Aksi | Baris |` dan perintah `git push`) **tetap wajib**.
- Bahasa: **Indonesia** untuk seluruh respons di mode ini.

### 12.6 Larangan Ajakan Eksekusi di Sesi yang Sama

Dalam mode §12, DILARANG menutup jawaban dengan ajakan memulai
pekerjaan, instruksi kerja, atau pertanyaan yang mendorong user untuk
langsung mengeksekusi di chat yang sama. Contoh yang dilarang (bukan
daftar lengkap):
- "Mari kita mulai...", "Siap mulai sekarang?", "Mau saya lanjut?".
- "Jalankan sekarang: ...", "Buka Acode dan lakukan ...", "Kirim file
  X sekarang untuk dianalisa", "Tempel hasil search-nya di sini".
- Instruksi lain yang mengasumsikan sesi ini adalah sesi kerja.

Aturan turunan:

- Sesi strategis **hanya** menghasilkan: keputusan, kritik,
  prioritas, atau artefak-siap-bawa. Sesi strategis DILARANG
  menghasilkan permintaan file, permintaan jalankan perintah, atau
  permintaan bukti/evidence dari user.
- Default pemisahan: **sesi strategis = perencanaan; sesi baru =
  eksekusi**. AI DILARANG mengasumsikan user ingin mengeksekusi di
  sesi berjalan kecuali user menyatakan eksplisit.
- Jika AI menilai langkah eksekusi perlu segera dilakukan, AI cukup
  menyatakannya sebagai rekomendasi bernada netral di bagian "Langkah
  ke Depan" atau "Aturan" — bukan sebagai pertanyaan penutup.
- Jika ragu apakah user ingin perencanaan atau eksekusi, AI WAJIB
  bertanya **di awal** (satu pertanyaan singkat, tanpa kode, tanpa
  instruksi kerja), bukan menebak lalu menawarkan eksekusi di akhir.

## 13. 🔴 KONTRAK LINTER (`analysis_options.yaml`) — WAJIB

### 13.1 Sumber Kebenaran

- `analysis_options.yaml` di root repo adalah **sumber kebenaran** untuk
  seluruh aturan analyzer & linter proyek ini.
- §13 hanyalah **ringkasan operasional**. Jika ada perbedaan antara §13
  dan `analysis_options.yaml`, maka **`analysis_options.yaml` yang menang**
  (karena dialah yang dieksekusi GitHub Actions).
- Jika ada aturan di `analysis_options.yaml` yang belum tercantum di §13,
  aturan tersebut **tetap berlaku** dan wajib dipatuhi.
- Jika AI perlu memverifikasi aturan yang tidak tercantum di §13, AI
  **WAJIB** meminta user mengirim ulang isi `analysis_options.yaml`
  sebelum menulis kode — bukan mengasumsikan.

### 13.2 Aturan Analyzer — Level ERROR (tidak bisa dinegosiasikan)

Pelanggaran berikut akan **menggagalkan build** di GitHub Actions:

- `unused_import: error`
- `unused_local_variable: error`
- `unused_field: error`
- `unnecessary_cast: error`
- `unnecessary_null_comparison: error`

### 13.3 Aturan Linter Tambahan (di luar `flutter_lints` default)

Wajib dipatuhi di seluruh file `lib/` dan `test/`:

- `prefer_const_constructors: true`
- `prefer_const_literals_to_create_immutables: true`
- `avoid_print: true`
- `unawaited_futures: true`
- `always_declare_return_types: true`
- `prefer_final_locals: true`
- `prefer_final_fields: true`

Include `package:flutter_lints/flutter.yaml` juga aktif — seluruh aturan
dasar `flutter_lints` tetap berlaku dan tidak boleh dilanggar.

### 13.4 Implikasi Praktis (WAJIB diterapkan)

- **`.withValues()`** → DILARANG. Gunakan `.withOpacity()` (Flutter 3.24).
- **`avoid_print`** → DILARANG memakai `print()` di `lib/`. Untuk
  debugging gunakan `debugPrint()` (dari `package:flutter/foundation.dart`)
  atau `developer.log()`. Menulis `// ignore: avoid_print` **DILARANG**
  kecuali ada alasan tertulis yang disetujui user. Di `test/` boleh
  memakai `print` hanya jika benar-benar perlu.
- **`unawaited_futures`** → Setiap `Future` yang tidak di-`await` dan
  tidak di-`return` WAJIB dibungkus `unawaited(...)` dari `dart:async`.
- **`always_declare_return_types`** → Semua fungsi/method WAJIB punya
  tipe return eksplisit (`void`, `Future<void>`, `Widget`, `int`, dst).
  Dilarang mengandalkan `dynamic` jika tipe statis memungkinkan.
- **`prefer_const_constructors`** + **`prefer_const_literals_to_create_immutables`**
  → Setiap widget/objek yang bisa `const` WAJIB `const`. Termasuk list,
  map, dan set literal yang isinya compile-time constant.
- **`prefer_final_locals`** → Variabel lokal yang tidak di-reassign WAJIB
  `final` (atau `const` jika bisa compile-time).
- **`prefer_final_fields`** → Field class yang tidak di-reassign setelah
  inisialisasi WAJIB `final`.
- **`unused_import`** → Import yang tidak dipakai WAJIB dihapus, bukan
  diberi `// ignore`.
- **`unused_local_variable`** → Variabel lokal yang tidak dipakai WAJIB
  dihapus, bukan di-rename jadi `_`.
- **`unused_field`** → Field yang tidak dipakai WAJIB dihapus (kecuali
  memang bagian dari API publik yang dipakai via refleksi — jarang di
  proyek ini).
- **`unnecessary_cast`** → DILARANG `as Tipe` jika tipe sudah diketahui
  oleh analyzer.
- **`unnecessary_null_comparison`** → DILARANG `x != null` jika `x`
  bertipe non-nullable.

### 13.5 Checklist WAJIB Sebelum Jawab (khusus linter)

- [ ] Tidak ada `.withValues()` (wajib `.withOpacity()`).
- [ ] Tidak ada `print()` di file `lib/` (kecuali diberi alasan tertulis).
- [ ] Setiap `Future` yang tidak di-`await` dibungkus `unawaited()`.
- [ ] Setiap fungsi/method punya tipe return eksplisit.
- [ ] `const` dipakai di manapun memungkinkan (constructor + literal).
- [ ] Variabel lokal yang tidak di-reassign memakai `final`/`const`.
- [ ] Field class yang tidak di-reassign memakai `final`.
- [ ] Tidak ada `unused_import`, `unused_local_variable`, `unused_field`,
      `unnecessary_cast`, `unnecessary_null_comparison`.
- [ ] Tidak ada `// ignore:` yang dipakai untuk "menyembunyikan" error
      linter (kecuali disetujui user secara eksplisit).

### 13.6 Hubungan dengan §3

- §3 adalah ringkasan singkat. §13 adalah penjabaran lengkap.
- Jika §3 dan §13 berbeda, **§13 yang menang**. Dan §13 selalu tunduk
  pada `analysis_options.yaml`.

### 13.7 Meta-Rule Sinkronisasi

- Menambah, menghapus, atau mengubah aturan di `analysis_options.yaml`
  **WAJIB** disertai update §13 di sesi yang sama.
- Mengubah §13 tanpa mengubah `analysis_options.yaml` hanya boleh untuk
  **klarifikasi/penjelasan**, bukan untuk menambah/menghapus aturan.
- Jika AI mendeteksi §13 tidak sinkron dengan `analysis_options.yaml`
  (misal user mengirim keduanya dan ada perbedaan), AI **WAJIB**
  memberitahu user dan menawarkan update §13 — bukan diam-diam memilih
  salah satu.