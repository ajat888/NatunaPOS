import json
from http.server import BaseHTTPRequestHandler
import requests
from api._shared import verify_jwt, SUPABASE_URL, SUPABASE_SERVICE_KEY


def get_store_id():
    r = requests.get(
        f'{SUPABASE_URL}/rest/v1/stores',
        params={'select': 'id', 'limit': '1'},
        headers={
            'apikey': SUPABASE_SERVICE_KEY,
            'Authorization': f'Bearer {SUPABASE_SERVICE_KEY}',
        },
        timeout=10,
    )
    if r.status_code != 200 or not r.json():
        return None
    return str(r.json()[0]['id'])


def save_subscription(store_id, uid, sub):
    keys = sub.get('keys', {})
    payload = {
        'store_id': store_id,
        'user_id': uid,
        'endpoint': sub['endpoint'],
        'p256dh': keys.get('p256dh', ''),
        'auth': keys.get('auth', ''),
    }
    r = requests.post(
        f'{SUPABASE_URL}/rest/v1/push_subscriptions',
        params={'on_conflict': 'endpoint'},
        headers={
            'apikey': SUPABASE_SERVICE_KEY,
            'Authorization': f'Bearer {SUPABASE_SERVICE_KEY}',
            'Content-Type': 'application/json',
            'Prefer': 'resolution=merge-duplicates',
        },
        data=json.dumps(payload),
        timeout=10,
    )
    return r.status_code in (200, 201, 204)


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
        try:
            length = int(self.headers.get('Content-Length', 0))
            raw = self.rfile.read(length) if length else b'{}'
            body = json.loads(raw.decode('utf-8'))
        except Exception:
            self._respond(400, {'error': 'Format JSON tidak valid'})
            return

        sub = body.get('subscription') or {}
        if not sub.get('endpoint') or not sub.get('keys', {}).get('p256dh') or not sub.get('keys', {}).get('auth'):
            self._respond(400, {'error': 'Data langganan tidak lengkap'})
            return

        auth = self.headers.get('Authorization', '')
        jwt = auth.replace('Bearer ', '').strip() if auth.startswith('Bearer ') else ''
        uid = verify_jwt(jwt)
        if not uid:
            self._respond(401, {'error': 'Sesi tidak valid. Silakan login ulang.'})
            return

        store_id = get_store_id()
        if not store_id:
            self._respond(500, {'error': 'Data toko tidak ditemukan'})
            return

        if not save_subscription(store_id, uid, sub):
            self._respond(500, {'error': 'Gagal menyimpan langganan'})
            return
        self._respond(200, {'saved': True})
