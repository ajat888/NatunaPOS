import os
import json
import time
from datetime import datetime
from http.server import BaseHTTPRequestHandler
import requests
from api._shared import verify_jwt, validate_pin, verify_pin

GROQ_API_KEY = os.environ.get('GROQ_API_KEY', '')
GROQ_URL = 'https://api.groq.com/openai/v1/chat/completions'

# DAFTAR MODEL FALLBACK (Dicoba berurutan dari atas ke bawah)
MODELS_TO_TRY = [
    'openai/gpt-oss-120b',        # Model utama (paling pintar, pengganti llama-3.3)
    'llama-3.1-8b-instant',       # Model cadangan 1 (sangat cepat & ringan)
    'openai/gpt-oss-20b',         # Model cadangan 2
    'gemma2-9b-it',               # Model cadangan 3
]


def _fmt(n):
    try:
        return f'{int(n):,}'.replace(',', '.')
    except Exception:
        return str(n)


DAY_NAMES = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu']


def _delta(cur, prev):
    d = int(cur or 0) - int(prev or 0)
    if d > 0:
        return f"naik Rp {_fmt(d)}"
    if d < 0:
        return f"turun Rp {_fmt(-d)}"
    return 'sama'


def _pola_hari(daily, exclude_date=None):
    # Rata-rata omzet per nama hari. Tanggal yang belum selesai dikecualikan.
    per_hari = {}
    for d in daily:
        if exclude_date and d.get('date') == exclude_date:
            continue
        try:
            wd = datetime.strptime(d.get('date', ''), '%Y-%m-%d').weekday()
        except Exception:
            continue
        total, count = per_hari.get(wd, (0, 0))
        per_hari[wd] = (total + int(d.get('sales', 0) or 0), count + 1)
    rows = [(DAY_NAMES[wd], total // count, count)
            for wd, (total, count) in per_hari.items()]
    return sorted(rows, key=lambda x: (x[2] >= 4, x[1]), reverse=True)


def _jam_ramai(hourly):
    rows = []
    for h in hourly:
        try:
            rows.append((int(h.get('hour', 0)), int(h.get('sales', 0) or 0)))
        except Exception:
            continue
    return sorted(rows, key=lambda x: x[1], reverse=True)[:5]


def _build_prompt(report):
    period = report.get('period', {}) or {}
    summary = report.get('summary', {}) or {}
    products = report.get('products', []) or []
    daily = report.get('daily', []) or []
    expenses = report.get('expenses', []) or []
    voids = report.get('voids', []) or []
    comparison = report.get('comparison') or {}
    hourly = report.get('hourly') or []

    lines = []
    lines.append(f"PERIODE UTAMA: {period.get('from', '?')} s/d {period.get('to', '?')}")
    if period.get('partial_until'):
        lines.append(f"(data baru sampai pukul {period['partial_until']}, periode ini belum selesai)")
    lines.append('')
    lines.append('RINGKASAN:')
    lines.append(f"- Total pemasukan: Rp {_fmt(summary.get('total_sales', 0))}")
    lines.append(f"- Total transaksi: {summary.get('total_transactions', 0)}")
    lines.append(f"- Total HPP: Rp {_fmt(summary.get('total_hpp', 0))}")
    lines.append(f"- Total pengeluaran: Rp {_fmt(summary.get('total_expenses', 0))}")
    lines.append(f"- Laba kotor: Rp {_fmt(summary.get('gross_profit', 0))}")
    lines.append(f"- Laba bersih: Rp {_fmt(summary.get('net_profit', 0))}")
    lines.append(f"- Void: {summary.get('void_count', 0)} transaksi senilai Rp {_fmt(summary.get('void_amount', 0))}")
    lines.append('')

    if comparison:
        cp = comparison.get('period', {}) or {}
        until = f" sampai pukul {cp['until_time']}" if cp.get('until_time') else ''
        cur_gross = int(summary.get('total_sales', 0) or 0) - int(summary.get('total_hpp', 0) or 0)
        prev_gross = int(comparison.get('total_sales', 0) or 0) - int(comparison.get('total_hpp', 0) or 0)
        lines.append('PEMBANDING (periode penuh sebelumnya dengan panjang sama):')
        lines.append(f"- Periode: {cp.get('from', '?')} s/d {cp.get('to', '?')}{until}")
        lines.append(f"- Penjualan periode utama dibanding pembanding: {_delta(summary.get('total_sales', 0), comparison.get('total_sales', 0))}")
        lines.append(f"- Transaksi: {summary.get('total_transactions', 0)} vs {comparison.get('total_transactions', 0)}")
        lines.append(f"- Untung kotor: {_delta(cur_gross, prev_gross)}")
        lines.append(f"- Pengeluaran: {_delta(summary.get('total_expenses', 0), comparison.get('total_expenses', 0))}")
        lines.append(f"- Void: {_delta(summary.get('void_amount', 0), comparison.get('void_amount', 0))}")
        lines.append('')

    partial_date = period.get('to') if period.get('partial_until') else None
    pola = _pola_hari(daily, partial_date)
    if pola:
        lines.append('POLA HARI (rata-rata penjualan per nama hari, seluruh periode):')
        for name, avg, n in pola:
            if n < 4:
                lines.append(f"- {name}: belum cukup data ({n} hari)")
            else:
                lines.append(f"- {name}: rata-rata Rp {_fmt(avg)} dari {n} hari")
        lines.append('')

    jam = _jam_ramai(hourly)
    if jam:
        lines.append('JAM RAMAI (akumulasi penjualan per jam, seluruh periode):')
        for h, sales in jam:
            lines.append(f"- Pukul {h:02d}:00 sampai {h:02d}:59: Rp {_fmt(sales)}")
        lines.append('')

    be = report.get('break_even') or {}
    if be:
        lines.append('TITIK IMPAS BIAYA TETAP:')
        lines.append(f"- Biaya tetap per bulan: Rp {_fmt(be.get('monthly', 0))}")
        lines.append(f"- Target biaya tetap periode ini: Rp {_fmt(be.get('target_periode', 0))}")
        lines.append(f"- Kontribusi periode ini (laba kotor dikurangi pengeluaran): Rp {_fmt(be.get('kontribusi_periode', 0))}")
        lines.append(f"- Sisa biaya tetap yang belum tertutup: Rp {_fmt(be.get('sisa_biaya_periode', 0))}")
        if be.get('sisa_hari') is not None:
            lines.append(f"- Sisa hari di bulan ini: {be.get('sisa_hari', 0)}")
            need = be.get('omzet_harian_dibutuhkan')
            if need is None:
                lines.append("- Total omzet harian yang dibutuhkan untuk impas: belum bisa dihitung (penjualan atau margin kotor bulan ini nol atau minus)")
            else:
                lines.append(f"- Total omzet harian yang dibutuhkan untuk impas (seluruh omzet per hari di sisa bulan, BUKAN tambahan di atas rata-rata sekarang): Rp {_fmt(need)}")
            lines.append(f"- Rata-rata omzet harian bulan ini: Rp {_fmt(be.get('omzet_harian_rata_rata', 0))}")
        lines.append('')

    if products:
        lines.append('PRODUK TERJUAL (urut omzet tertinggi):')
        for p in products[:20]:
            lines.append(
                f"- {p.get('name', '?')}: {p.get('qty_sold', 0)} porsi terjual, "
                f"omzet Rp {_fmt(p.get('revenue', 0))}, untung Rp {_fmt(p.get('profit', 0))}, "
                f"untung per porsi Rp {_fmt(p.get('unit_profit', 0))} "
                f"(harga jual Rp {_fmt(p.get('unit_price', 0))}, modal bahan Rp {_fmt(p.get('unit_hpp', 0))})"
            )
        lines.append('')

    if daily:
        lines.append('TREN HARIAN:')
        for d in daily[:31]:
            lines.append(f"- {d.get('date', '?')}: Rp {_fmt(d.get('sales', 0))} dari {d.get('tx_count', 0)} transaksi")
        lines.append('')

    lines.append(f"Total pengeluaran (semua entri): Rp {_fmt(summary.get('total_expenses', 0))}")
    lines.append('')
    if expenses:
        lines.append(f'PENGELUARAN ({len(expenses)} entri, ditampilkan maks 30 di bawah ini; angka total di atas mencakup semua entri):')
        for e in expenses[:30]:
            lines.append(f"- {e.get('item_name', '?')} ({e.get('category_name', '?')}): Rp {_fmt(e.get('amount', 0))} pada {e.get('created_at', '?')}")
        lines.append('')

    if voids:
        lines.append(f'VOID ({len(voids)} entri, ditampilkan maks 20):')
        for v in voids[:20]:
            lines.append(f"- Rp {_fmt(v.get('total', 0))} oleh {v.get('voided_by', '?')} pada {v.get('voided_at', '?')}: \"{v.get('reason', '?')}\"")
        lines.append('')

    data_text = '\n'.join(lines)

    return f"""Anda adalah pendamping bisnis untuk pemilik warung/resto kecil di Indonesia. Pemilik ini awam akuntansi dan perlu informasi yang cepat dipahami.

ATURAN WAJIB:
1. DILARANG menggunakan persentase (%). Gunakan Rupiah atau jumlah absolut.
2. Total periode utama sudah tampil di layar, jadi jangan diulang. Sebut angka pembanding dan selisihnya saja.
3. DILARANG mengarang angka. Semua angka harus berasal dari DATA LAPORAN. Angka 0 pada PEMBANDING hanya berarti tidak ada data pada periode pembanding. DILARANG menyimpulkan sebab, misalnya "belum ada penjualan", tanpa dasar data.
4. Gunakan bahasa Indonesia sehari-hari. Ganti istilah: HPP menjadi "modal bahan", margin menjadi "untung per porsi", laba kotor menjadi "untung sebelum biaya operasional".
5. Setiap saran harus KONKRET, bisa dilakukan minggu ini, dan menyebut target Rupiah.
6. Format Markdown, maksimal 400 kata. Jangan tulis kalimat pembuka, langsung ke isi.
7. "Total omzet harian yang dibutuhkan" adalah TOTAL omzet per hari di sisa bulan, BUKAN tambahan di atas rata-rata sekarang. Bandingkan langsung dengan "Rata-rata omzet harian (total)". Jika POLA HARI menulis "belum cukup data", jangan menyebut rata-rata untuk hari itu. Angka apa pun yang tidak ada di DATA LAPORAN dilarang ditulis.

STRUKTUR OUTPUT (WAJIB):

## 📊 Hari Ini vs Pembanding
2-3 poin. Sebut apakah penjualan naik atau turun dibanding pembanding, berapa selisihnya dalam Rupiah, dan kemungkinan penyebabnya dari data. Jika data menyebut "belum selesai", jelaskan singkat bahwa pembanding adalah hari penuh sehingga selisihnya belum final.

## ⚠️ Perhatikan
Hal yang perlu diwaspadai: void yang tidak wajar (sebut nominal dan siapa yang melakukannya), pengeluaran besar, atau menu dengan untung per porsi kecil. Jika tidak ada, tulis "Tidak ada yang mendesak."

## 🚀 Strategi 7 Hari Ke Depan
3 langkah konkret. Pilih menu HANYA dari bagian PRODUK TERJUAL, dengan aturan:
- Promosikan menu dengan untung per porsi TINGGI tetapi qty terjual RENDAH (potensi belum tergali), atau menu untung tinggi yang sudah laku untuk didorong volumenya.
- Hindari mempromosikan menu dengan untung per porsi kecil kecuali sebagai pancingan dan sebutkan kerugiannya.
- Tulis perhitungan singkat dari angka data, misalnya: untung per porsi Rp X × target porsi per hari Y = Rp Z per hari. Jangan menulis target yang tidak bisa diturunkan dari angka DATA LAPORAN.
- Jangan mengarang harga paket, diskon, atau paket baru yang tidak ada di data. Jika menyarankan paket atau diskon, tulis hanya sebagai uji coba dan sebutkan angka modal yang dipakai.
- Gunakan POLA HARI dan JAM RAMAI hanya untuk menentukan waktu promosi, bukan untuk memilih menu.
def _build_prompt(report):
    period = report.get('period', {}) or {}
    summary = report.get('summary', {}) or {}
    products = report.get('products', []) or []
    daily = report.get('daily', []) or []
    expenses = report.get('expenses', []) or []
    voids = report.get('voids', []) or []
    comparison = report.get('comparison') or {}
    hourly = report.get('hourly') or []

    lines = []
    lines.append(f"PERIODE UTAMA: {period.get('from', '?')} s/d {period.get('to', '?')}")
    if period.get('partial_until'):
        lines.append(f"(data baru sampai pukul {period['partial_until']}, periode ini belum selesai)")
    lines.append('')
    lines.append('RINGKASAN:')
    lines.append(f"- Pemasukan: Rp {_fmt(summary.get('total_sales', 0))}")
    lines.append(f"- Total transaksi: {summary.get('total_transactions', 0)}")
    lines.append(f"- Modal bahan (HPP): Rp {_fmt(summary.get('total_hpp', 0))}")
    lines.append(f"- Belanja bahan (stok, tidak mengurangi untung): Rp {_fmt(summary.get('total_stock_purchases', 0))}")
    lines.append(f"- Untung kotor: Rp {_fmt(summary.get('gross_profit', 0))}")
    lines.append(f"- Untung bersih: Rp {_fmt(summary.get('net_profit', 0))}")
    lines.append(f"- Void: {summary.get('void_count', 0)} transaksi senilai Rp {_fmt(summary.get('void_amount', 0))}")
    lines.append('')

    if comparison:
        cp = comparison.get('period', {}) or {}
        until = f" sampai pukul {cp['until_time']}" if cp.get('until_time') else ''
        cur_gross = int(summary.get('total_sales', 0) or 0) - int(summary.get('total_hpp', 0) or 0)
        prev_gross = int(comparison.get('total_sales', 0) or 0) - int(comparison.get('total_hpp', 0) or 0)
        lines.append('PEMBANDING (periode penuh sebelumnya dengan panjang sama):')
        lines.append(f"- Periode: {cp.get('from', '?')} s/d {cp.get('to', '?')}{until}")
        lines.append(f"- Pemasukan periode utama dibanding pembanding: {_delta(summary.get('total_sales', 0), comparison.get('total_sales', 0))}")
        lines.append(f"- Transaksi: {summary.get('total_transactions', 0)} vs {comparison.get('total_transactions', 0)}")
        lines.append(f"- Untung kotor: {_delta(cur_gross, prev_gross)}")
        lines.append(f"- Pengeluaran lain: {_delta(summary.get('total_expenses', 0), comparison.get('total_expenses', 0))}")
        lines.append(f"- Belanja bahan (stok, tidak mengurangi untung): Rp {_fmt(summary.get('total_stock_purchases', 0))}")
        lines.append(f"- Void: {_delta(summary.get('void_amount', 0), comparison.get('void_amount', 0))}")
        lines.append('')

    partial_date = period.get('to') if period.get('partial_until') else None
    pola = _pola_hari(daily, partial_date)
    if pola:
        lines.append('POLA HARI (rata-rata pemasukan per nama hari, seluruh periode):')
        for name, avg, n in pola:
            if n < 4:
                lines.append(f"- {name}: belum cukup data ({n} hari)")
            else:
                lines.append(f"- {name}: rata-rata Rp {_fmt(avg)} dari {n} hari")
        lines.append('')

    jam = _jam_ramai(hourly)
    if jam:
        lines.append('JAM RAMAI (akumulasi pemasukan per jam, seluruh periode):')
        for h, sales in jam:
            lines.append(f"- Pukul {h:02d}:00 sampai {h:02d}:59: Rp {_fmt(sales)}")
        lines.append('')

    be = report.get('break_even') or {}
    if be:
        lines.append('TITIK IMPAS (pemasukan minimal agar tidak rugi):')
        lines.append(f"- Biaya tetap per bulan (listrik, gaji, sewa, dan sejenisnya): Rp {_fmt(be.get('monthly', 0))}")
        lines.append(f"- Target biaya tetap periode ini: Rp {_fmt(be.get('target_periode', 0))}")
        lines.append(f"- Untung bersih periode ini (sudah dikurangi pengeluaran lain): Rp {_fmt(be.get('kontribusi_periode', 0))}")
        lines.append(f"- Biaya tetap yang belum tertutup untung bersih: Rp {_fmt(be.get('sisa_biaya_periode', 0))}")
        if be.get('sisa_hari') is not None:
            lines.append(f"- Sisa hari di bulan ini: {be.get('sisa_hari', 0)}")
            need = be.get('omzet_harian_dibutuhkan')
            if need is None:
                lines.append("- Pemasukan per hari yang dibutuhkan untuk impas: belum bisa dihitung (pemasukan atau untung kotor bulan ini nol atau minus)")
            else:
                lines.append(f"- Pemasukan per hari yang dibutuhkan untuk impas (angka total per hari di sisa bulan, BUKAN tambahan dari rata-rata): Rp {_fmt(need)}")
            lines.append(f"- Rata-rata pemasukan per hari bulan ini: Rp {_fmt(be.get('omzet_harian_rata_rata', 0))}")
        lines.append('')

    if products:
        lines.append('PRODUK TERJUAL (urut pemasukan tertinggi):')
        for p in products[:20]:
            lines.append(
                f"- {p.get('name', '?')}: {p.get('qty_sold', 0)} porsi terjual, "
                f"pemasukan Rp {_fmt(p.get('revenue', 0))}, untung Rp {_fmt(p.get('profit', 0))}, "
                f"untung per porsi Rp {_fmt(p.get('unit_profit', 0))} "
                f"(harga jual Rp {_fmt(p.get('unit_price', 0))}, modal bahan Rp {_fmt(p.get('unit_hpp', 0))})"
            )
        lines.append('')

    if daily:
        lines.append('TREN HARIAN:')
        for d in daily[:31]:
            lines.append(f"- {d.get('date', '?')}: Rp {_fmt(d.get('sales', 0))} dari {d.get('tx_count', 0)} transaksi")
        lines.append('')

    lines.append(f"Total pengeluaran lain (semua entri): Rp {_fmt(summary.get('total_expenses', 0))}")
    lines.append('')
    if expenses:
        lines.append(f'PENGELUARAN LAIN ({len(expenses)} entri, ditampilkan maks 30 di bawah ini; angka total di atas mencakup semua entri):')
        for e in expenses[:30]:
            lines.append(f"- {e.get('item_name', '?')} ({e.get('category_name', '?')}): Rp {_fmt(e.get('amount', 0))} pada {e.get('created_at', '?')}")
        lines.append('')

    if voids:
        lines.append(f'VOID ({len(voids)} entri, ditampilkan maks 20):')
        for v in voids[:20]:
            lines.append(f"- Rp {_fmt(v.get('total', 0))} oleh {v.get('voided_by', '?')} pada {v.get('voided_at', '?')}: \"{v.get('reason', '?')}\"")
        lines.append('')

    data_text = '\n'.join(lines)

    return f"""Anda adalah pendamping bisnis untuk pemilik warung/resto kecil di Indonesia. Pemilik ini awam akuntansi dan perlu informasi yang cepat dipahami.

ATURAN WAJIB:
1. DILARANG menggunakan persentase (%). Gunakan Rupiah atau jumlah absolut.
2. Total periode utama sudah tampil di layar, jadi jangan diulang. Sebut angka pembanding dan selisihnya saja.
3. DILARANG mengarang angka. Semua angka harus berasal dari DATA LAPORAN. Angka 0 pada PEMBANDING hanya berarti tidak ada data pada periode pembanding. DILARANG menyimpulkan sebab tanpa dasar data.
4. Pakai istilah ini saja: Pemasukan, Modal bahan, Untung kotor, Pengeluaran lain, Untung bersih, Untung per porsi, Titik impas. Jangan memakai HPP, omzet, laba, margin, atau kontribusi.
5. Setiap saran harus KONKRET, bisa dilakukan minggu ini, dan menyebut target dalam Rupiah. Target diturunkan dari angka DATA LAPORAN, misalnya rata-rata per hari dari TREN HARIAN.
6. Format Markdown, maksimal 400 kata. Jangan tulis kalimat pembuka, langsung ke isi. Tulis angka dengan format Rp, misalnya Rp 150.000.
7. "Pemasukan per hari yang dibutuhkan untuk impas" adalah total per hari di sisa bulan, BUKAN tambahan di atas rata-rata. Bandingkan langsung dengan "Rata-rata pemasukan per hari bulan ini". Jika POLA HARI menulis "belum cukup data", jangan menyebut rata-rata untuk hari itu.

STRUKTUR OUTPUT (WAJIB):

## 📊 Hari Ini vs Pembanding
2-3 poin. Sebut apakah pemasukan naik atau turun dibanding pembanding, berapa selisihnya dalam Rupiah, dan kemungkinan penyebabnya dari data. Jika data menyebut "belum selesai", jelaskan singkat bahwa pembanding adalah hari penuh sehingga selisihnya belum final.

## ⚠️ Perhatikan
Hal yang perlu diwaspadai: void yang tidak wajar (sebut nominal dan siapa yang melakukannya), pengeluaran lain yang besar, atau menu dengan untung per porsi kecil. Jika tidak ada, tulis "Tidak ada yang mendesak."

## 🚀 Strategi 7 Hari Ke Depan
3 langkah konkret. Pilih menu HANYA dari bagian PRODUK TERJUAL, dengan aturan:
- Dorong menu dengan untung per porsi TINGGI tetapi qty terjual RENDAH (potensi belum tergali), atau menu untung tinggi yang sudah laku untuk diperbesar volumenya.
- Hindari mendorong menu dengan untung per porsi kecil kecuali sebagai pancingan, dan sebutkan risikonya.
- Tulis perhitungan singkat dari angka data, misalnya: untung per porsi Rp X × porsi per hari Y = Rp Z per hari. Porsi per hari dihitung dari qty terjual dibagi jumlah hari pada periode.
- Jangan mengarang harga paket, diskon, atau menu baru yang tidak ada di data. Jika menyarankan paket atau diskon, tulis hanya sebagai uji coba dan sebutkan modal yang dipakai.
- Gunakan POLA HARI dan JAM RAMAI hanya untuk menentukan waktu promosi, bukan untuk memilih menu.
- Jika TITIK IMPAS menunjukkan pemasukan harian yang dibutuhkan jauh di atas rata-rata sekarang, katakan terus terang bahwa promosi saja tidak cukup untuk impas bulan ini.

## 🎯 Titik Impas
1-2 kalimat dalam Rupiah. Hanya jika ada data TITIK IMPAS. Jika tidak ada, lewati bagian ini.

---

DATA LAPORAN:

{data_text}
"""


class handler(BaseHTTPRequestHandler):
    def _respond(self, status, body):
        data = json.dumps(body).encode('utf-8')
        self.send_response(status)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(data)))
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Headers', 'authorization, content-type')
        self.send_header('Access-Control-Allow-Methods', 'POST, OPTIONS')
        self.end_headers()
        self.wfile.write(data)

    def do_OPTIONS(self):
        self._respond(200, {})

    def do_POST(self):
        if not GROQ_API_KEY:
            self._respond(500, {'error': 'Server belum dikonfigurasi (GROQ_API_KEY kosong)'})
            return

        try:
            length = int(self.headers.get('Content-Length', 0))
            raw = self.rfile.read(length) if length else b'{}'
            body = json.loads(raw.decode('utf-8'))
        except Exception:
            self._respond(400, {'error': 'Format JSON tidak valid'})
            return

        auth = self.headers.get('Authorization', '')
        jwt = auth.replace('Bearer ', '').strip() if auth.startswith('Bearer ') else ''
        uid = verify_jwt(jwt)
        if not uid:
            self._respond(401, {'error': 'Sesi tidak valid. Silakan login ulang.'})
            return

        pin = body.get('pin', '')
        if not validate_pin(pin):
            self._respond(400, {'error': 'PIN tidak valid'})
            return
        pin_result = verify_pin(uid, pin)
        if not pin_result.get('valid'):
            if pin_result.get('reason') == 'locked':
                self._respond(429, {'error': 'PIN terkunci sementara. Coba lagi nanti.'})
                return
            self._respond(401, {'error': 'PIN salah'})
            return

        report = body.get('report', {})
        if not report:
            self._respond(400, {'error': 'Data laporan kosong'})
            return

        prompt = _build_prompt(report)

        last_error = None
        success_model = None
        analysis_result = None

        # LOOPING FALLBACK: Coba satu per satu
        for model_name in MODELS_TO_TRY:
            try:
                groq_resp = requests.post(
                    GROQ_URL,
                    headers={
                        'Authorization': f'Bearer {GROQ_API_KEY}',
                        'Content-Type': 'application/json',
                    },
                    json={
                        'model': model_name,
                        'messages': [
                            {'role': 'system', 'content': 'Anda adalah analis bisnis F&B Indonesia. Jawab dalam Markdown.'},
                            {'role': 'user', 'content': prompt},
                        ],
                        'temperature': 0.4,
                        'max_tokens': 3000, # Naikkan max_tokens untuk model reasoning
                    },
                    timeout=60,
                )

                if groq_resp.status_code == 200:
                    data = groq_resp.json()
                    analysis_result = data['choices'][0]['message']['content']
                    success_model = model_name
                    break # Berhasil, keluar dari loop
                else:
                    last_error = f'{model_name} error ({groq_resp.status_code})'
                    # Lanjut ke model berikutnya
            except requests.exceptions.RequestException as e:
                last_error = f'{model_name} koneksi gagal: {e}'
                # Lanjut ke model berikutnya

        if analysis_result is not None:
            self._respond(200, {
                'analysis': analysis_result.strip(),
                'model': success_model,
            })
        else:
            self._respond(500, {'error': f'Semua model gagal. Error terakhir: {last_error}'})