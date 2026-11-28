# Pelajaran NatunaPOS

Catatan kesalahan nyata yang sudah pernah terjadi di repo ini, beserta pengamannya.
Tujuannya: kesalahan yang sama tidak terulang.

**Cara pakai:** di awal sesi baru, minta AI membaca file ini
(misal: "baca docs/PELAJARAN.md"). Model tidak mengingat sesi sebelumnya;
file inilah penggantinya.

---

## P1. File Python rusak tidak selalu terlihat

**Gejala:** analisis AI di layar Laporan gagal dengan
`Respons server tidak valid (HTTP 404)`.

**Penyebab:** `api/analyze.py` berisi dua `def _build_prompt` dan satu
f-string `"""` yang tidak ditutup, jadi file itu SyntaxError. Fungsi
`/api/analyze` tidak terbentuk di Vercel; request jatuh ke 404 NOT_FOUND
(halaman HTML), lalu klien gagal `jsonDecode`.

**Pengaman:**

- Setiap habis mengubah `api/*.py`, jalankan `python3 -m py_compile api/*.py`.
- Saat merombak blok prompt yang panjang, jangan menyalin ulang f-string
  besar; jadikan konstanta terpisah supaya batas string tidak bergeser.
- Setelah deploy, uji endpoint aslinya. Deployment "sukses" bukan bukti
  fungsinya ada.

## P2. Bedakan 404 dan 500 sebelum menyimpulkan

**Gejala:** dua bug berbeda terlihat sama di aplikasi.

**Cara cepat:** kirim POST dengan body `{}` ke endpoint, lalu lihat
status + `Content-Type`.

- `404` + `text/plain` = fungsi tidak terdaftar (build/route hilang).
- `500` + `application/json` = fungsi jalan, tapi error di dalamnya.
- `401` + `application/json` = fungsi hidup, autentikasi menolak.

Contoh nyata: `/api/pin` membalas 401 JSON (sehat) sementara
`/api/analyze` membalas 404 text/plain (hilang).

## P3. Pesan error generik memperlambat diagnosis

**Gejala:** layar hanya menampilkan "Respons server tidak valid (HTTP 404)".

**Penyebab:** klien mencoba `jsonDecode` dulu; kalau gagal, status asli
dibuang dan badan respons tidak pernah disimpan.

**Pengaman:** saat menambah pemanggilan HTTP baru, sertakan status code
dan potongan badan respons di pesan error (atau di `debugPrint`), supaya
404/500/401 bisa dibedakan tanpa membuka server.

## P4. Perubahan kecil tetap bisa merusak file besar

**Gejala:** file yang tadinya jalan tiba-tiba gagal build.

**Penyebab:** edit "rapikan istilah" pada prompt AI menyalin blok lebih
dari 130 baris, sehingga fungsi terduplikasi.

**Pengaman:** untuk file > 200 baris, edit blok sekecil mungkin, lalu
periksa jumlah definisi fungsi setelah edit
(misal `grep -c "def _build_prompt" api/analyze.py` harus 1).

## P5. Jangan mengandalkan ingatan sesi

**Gejala:** keputusan dan penyebab bug hilang saat ganti chat.

**Pengaman:** tulis keputusan, gejala, dan langkah verifikasi ke file
repo (seperti `docs/PELAJARAN.md` ini). Chat baru dimulai dari file,
bukan dari ingatan.

## P6. Lingkungan kerja di HP

- Flutter tidak terpasang di proot; `flutter analyze` tidak bisa dijalankan
  lokal. Verifikasi yang bisa dilakukan: `py_compile`, tes Dart manual,
  dan pemeriksaan aturan di `analysis_options.yaml`.
- Identitas git bisa kosong di proot. Push tetap dari Termux
  (sesuai `AI_RULES.md` §1), atau set `user.name`/`user.email` sekali.
- Repo ada di `/sdcard/Documents/NatunaPOS`; jangan mengubah file di luar
  `lib/` dan `api/` tanpa alasan yang dijelaskan.

## P7. `catch` ganda membuat data ditolak diulang selamanya

**Gejala:** indikator sinkronisasi tidak pernah berhenti "menunggu"; jumlah
perubahan belum terkirim tetap > 0 walau jaringan normal; logout selalu
dicegat dialog "Data Belum Tersinkron"; void transaksi tidak sampai ke
server sehingga laporan di perangkat lain masih menghitung penjualan itu.

**Penyebab:** `_pushVoidedTransactions` punya dua `on PostgrestException`
bersarang (sisa commit `2a8607e`). Handler dalam hanya menjalankan
`_rejected++` tanpa menandai baris selesai, sedangkan
`markTransactionRejected` justru ditulis di handler luar yang praktis tidak
mungkin tereksekusi (error sudah ditangkap handler dalam). Baris tetap
`is_synced = 0`, jadi ikut terambil `getUnsyncedVoidedTransactions` di
setiap sync — berulang tanpa akhir.

**Pengaman:**

- Satu blok `try/catch` per operasi push. Jangan menyisakan handler luar
  yang menangani error yang sama; itu membuat perbaikan terlihat ada
  padahal mati.
- Setiap cabang "ditolak permanen" WAJIB memanggil `mark*Rejected` /
  `mark*Synced`, supaya `countPendingSync()` turun dan tombol logout
  tidak terkunci.
- Setelah mengubah `sync_runner_*`, periksa jumlah penangkap error
  (`grep -c "on PostgrestException" file`) dan pastikan tidak ada cabang
  `catch` tanpa perubahan status.

---

## Checklist sebelum push

- [ ] `python3 -m py_compile api/*.py` lolos (kalau `api/` berubah)
- [ ] Tidak ada file Dart > 500 baris; `part`/`part of` lengkap
- [ ] Tidak ada `.withValues()`, `print()`, import menganggur
- [ ] Kontrak `skipSync` / `WriteNotifier` tidak dilanggar
- [ ] Folder `android/` tidak tersentuh
- [ ] Setelah push, uji endpoint/APK yang berubah, bukan hanya status build
