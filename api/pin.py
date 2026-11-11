import json
from http.server import BaseHTTPRequestHandler
from _shared import (
    verify_jwt,
    hash_pin,
    generate_salt,
    validate_pin,
    get_pin_row,
    upsert_pin_row,
    patch_pin_row,
    delete_pin_row,
    verify_supabase_credentials,
    verify_pin,
)


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

        action = body.get('action', '')

        if action == 'reset':
            email = body.get('email', '').strip()
            password = body.get('password', '')
            uid = verify_supabase_credentials(email, password)
            if not uid:
                self._respond(401, {'error': 'Email atau password salah'})
                return
            delete_pin_row(uid)
            self._respond(200, {'reset': True})
            return

        auth = self.headers.get('Authorization', '')
        jwt = auth.replace('Bearer ', '').strip() if auth.startswith('Bearer ') else ''
        uid = verify_jwt(jwt)
        if not uid:
            self._respond(401, {'error': 'Sesi tidak valid. Silakan login ulang.'})
            return

        row = get_pin_row(uid)

        if action == 'status':
            if not row:
                self._respond(200, {'has_pin': False, 'locked_until_ms': 0})
                return
            self._respond(200, {
                'has_pin': True,
                'locked_until_ms': int(row.get('locked_until_ms', 0) or 0),
            })
            return

        if action == 'set':
            pin = body.get('pin', '')
            if not validate_pin(pin):
                self._respond(400, {'error': 'PIN harus 6 digit angka'})
                return
            if row:
                self._respond(409, {'error': 'PIN sudah ada. Gunakan fitur Ganti PIN.'})
                return
            salt = generate_salt()
            pin_hash = hash_pin(pin, salt)
            if not upsert_pin_row(uid, pin_hash, salt):
                self._respond(500, {'error': 'Gagal menyimpan PIN'})
                return
            self._respond(200, {'saved': True})
            return

        if action == 'verify':
            pin = body.get('pin', '')
            if not validate_pin(pin):
                self._respond(400, {'error': 'PIN harus 6 digit angka'})
                return
            result = verify_pin(uid, pin)
            if result.get('reason') == 'no_pin':
                self._respond(404, {'error': 'PIN belum dibuat'})
                return
            self._respond(200, {
                'valid': result.get('valid', False),
                'locked_until_ms': result.get('locked_until_ms', 0),
                'failed_attempts': result.get('failed_attempts', 0),
            })
            return

        if action == 'change':
            if not row:
                self._respond(404, {'error': 'PIN belum dibuat'})
                return
            old_pin = body.get('old_pin', '')
            new_pin = body.get('new_pin', '')
            if not validate_pin(old_pin) or not validate_pin(new_pin):
                self._respond(400, {'error': 'PIN harus 6 digit angka'})
                return
            result = verify_pin(uid, old_pin)
            if not result.get('valid'):
                self._respond(400, {'error': 'PIN lama salah'})
                return
            new_salt = generate_salt()
            new_hash = hash_pin(new_pin, new_salt)
            if not patch_pin_row(uid, {'pin_hash': new_hash, 'salt': new_salt}):
                self._respond(500, {'error': 'Gagal mengganti PIN'})
                return
            self._respond(200, {'changed': True})
            return

        self._respond(400, {'error': 'Action tidak dikenal'})