# Instruksi Proyek — NatunaPOS

Repo ini punya aturan kerja sendiri. Ikuti, jangan disimpulkan dari kebiasaan umum.

1. Sebelum bekerja, baca `AI_RULES.md` dan `docs/PELAJARAN.md`. Patuhi
   `AI_RULES.md` tanpa kecuali; jika bertentangan, `AI_RULES.md` menang.
2. Saat memperbaiki bug yang tidak tertangkap CI atau tes, tambahkan satu
   entri baru di `docs/PELAJARAN.md` pada commit yang sama. Format: gejala,
   penyebab, pengaman. Jangan mengubah entri lama tanpa alasan.
3. Balas dalam bahasa Indonesia. Akhiri jawaban dengan tabel
   `| Path | Aksi | Baris |` dan perintah git push tanpa `cd`.
4. Push dikerjakan sendiri, bukan diserahkan ke user. Setelah perubahan
   di-commit, jalankan `git push origin main` (remote SSH sudah siap),
   lalu laporkan hasilnya. Perintah push di butir 3 tetap ditulis untuk
   arsip, meski push sudah dilakukan.
