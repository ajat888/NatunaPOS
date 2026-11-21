import os
import json
import time
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


def _build_prompt(report):
    period = report.get('period', {}) or {}
    summary = report.get('summary', {}) or {}
    products = report.get('products', []) or []
    daily = report.get('daily', []) or []
    expenses = report.get('expenses', []) or []
    voids = report.get('voids', []) or []

    lines = []
    lines.append(f"PERIODE: {period.get('from', '?')} s/d {period.get('to', '?')}")
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
    be = report.get('break_even') or {}
    if be:
        lines.append('TITIK IMPAS BIAYA TETAP:')
        lines.append(f"- Biaya tetap per bulan: Rp {_fmt(be.get('monthly', 0))}")
        lines.append(f"- Target biaya tetap periode ini: Rp {_fmt(be.get('target_periode', 0))}")
        lines.append(f"- Kontribusi periode ini (laba kotor dikurangi pengeluaran): Rp {_fmt(be.get('kontribusi_periode', 0))}")
        lines.append(f"- Sisa biaya tetap yang belum tertutup: Rp {_fmt(be.get('sisa_biaya_periode', 0))}")
        if be.get('sisa_hari') is not None:
            lines.append(f"- Sisa hari di bulan ini: {be.get('sisa_hari', 0)}")
            lines.append(f"- Omzet harian yang dibutuhkan untuk impas: Rp {_fmt(be.get('omzet_harian_dibutuhkan', 0))}")
            lines.append(f"- Rata-rata omzet harian bulan ini: Rp {_fmt(be.get('omzet_harian_rata_rata', 0))}")
        lines.append('')

    if products:
        lines.append('PRODUK TERJUAL (urut omzet tertinggi):')
        for p in products[:20]:
            lines.append(
                f"- {p.get('name', '?')}: {p.get('qty_sold', 0)} porsi terjual, "
                f"omzet Rp {_fmt(p.get('revenue', 0))}, untung Rp {_fmt(p.get('profit', 0))}, "
                f"margin Rp {_fmt(p.get('unit_profit', 0))}/porsi "
                f"(harga jual Rp {_fmt(p.get('unit_price', 0))}, HPP Rp {_fmt(p.get('unit_hpp', 0))})"
            )
        lines.append('')

    if daily:
        lines.append('TREN HARIAN:')
        for d in daily[:31]:
            lines.append(f"- {d.get('date', '?')}: Rp {_fmt(d.get('sales', 0))} dari {d.get('tx_count', 0)} transaksi")
        lines.append('')

    if expenses:
        lines.append(f'PENGELUARAN ({len(expenses)} entri, ditampilkan maks 30):')
        for e in expenses[:30]:
            lines.append(f"- {e.get('item_name', '?')} ({e.get('category_name', '?')}): Rp {_fmt(e.get('amount', 0))} pada {e.get('created_at', '?')}")
        lines.append('')

    if voids:
        lines.append(f'VOID ({len(voids)} entri, ditampilkan maks 20):')
        for v in voids[:20]:
            lines.append(f"- Rp {_fmt(v.get('total', 0))} oleh {v.get('voided_by', '?')} pada {v.get('voided_at', '?')}: \"{v.get('reason', '?')}\"")
        lines.append('')

    data_text = '\n'.join(lines)

    return f"""Anda adalah analis bisnis untuk warung/resto kecil di Indonesia.

ATURAN WAJIB:
1. DILARANG menggunakan persentase (%). Semua angka dalam nominal Rupiah atau jumlah absolut.
2. DILARANG menghitung ulang atau menyebutkan Total Omzet, Total Pengeluaran, atau Laba Bersih. Angka tersebut sudah ditampilkan besar-besar di layar HP pengguna. Fokus Anda adalah INSIGHT (analisa), bukan kalkulasi dasar.
3. Gunakan bahasa Indonesia santai tapi profesional.
4. Setiap saran harus KONKRET dan BISA DILAKUKAN hari ini, bukan teori.
5. Sertakan angka nominal nyata dari data untuk mendukung analisa (misal: "selisih Rp 15.000").
6. Format Markdown. Maksimal 350 kata. Jangan tulis "Berikut adalah..." atau kalimat pembuka, langsung ke isi.

STRUKTUR OUTPUT (WAJIB):

## 🌟 Fokus Besok
1-2 kalimat. Pilih 2 menu dengan untung per porsi tertinggi DAN volume penjualan bagus. Beri saran promosi konkret.

## ⚠️ Pemborosan & Kerugian
Sebutkan pengeluaran yang nilainya besar (jika ada), atau menu dengan untung per porsi di bawah Rp 2.000 / HPP lebih besar dari harga jual. Sebut kerugian nominalnya.

## 📋 Aksi Cepat (3 Langkah)
3 langkah konkret untuk besok dengan target terukur, tanpa teori.

## 🎯 Titik Impas
1-2 kalimat. Sebut status impas dalam Rupiah: sisa biaya tetap yang belum tertutup, atau nyatakan sudah tercapai. Jika ada data sisa hari, bandingkan omzet harian yang dibutuhkan dengan rata-rata omzet harian sekarang. Jika data titik impas tidak ada di DATA LAPORAN, lewati bagian ini.

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