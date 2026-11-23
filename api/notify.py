import hmac
import json
import os
from datetime import datetime, timedelta, timezone
from http.server import BaseHTTPRequestHandler
import requests
from pywebpush import webpush, WebPushException
from api._shared import SUPABASE_URL, SUPABASE_SERVICE_KEY

NOTIFY_WEBHOOK_SECRET = os.environ.get('NOTIFY_WEBHOOK_SECRET', '')
VAPID_PRIVATE_KEY = os.environ.get('VAPID_PRIVATE_KEY', '')
VAPID_SUBJECT = os.environ.get('VAPID_SUBJECT', 'https://natunapos.vercel.app')
WIB = timezone(timedelta(hours=7))


def list_subscriptions():
    r = requests.get(
        f'{SUPABASE_URL}/rest/v1/push_subscriptions',
        params={'select': 'endpoint,p256dh,auth'},
        headers={
            'apikey': SUPABASE_SERVICE_KEY,
            'Authorization': f'Bearer {SUPABASE_SERVICE_KEY}',
        },
        timeout=10,
    )
    if r.status_code != 200:
        return []
    return r.json()


def delete_subscription(endpoint):
    requests.delete(
        f'{SUPABASE_URL}/rest/v1/push_subscriptions',
        params={'endpoint': f'eq.{endpoint}'},
        headers={
            'apikey': SUPABASE_SERVICE_KEY,
            'Authorization': f'Bearer {SUPABASE_SERVICE_KEY}',
        },
        timeout=10,
    )


def send_one(sub, payload):
    try:
        webpush(
            subscription_info={
                'endpoint': sub['endpoint'],
                'keys': {'p256dh': sub['p256dh'], 'auth': sub['auth']},
            },
            data=json.dumps(payload),
            vapid_private_key=VAPID_PRIVATE_KEY,
            vapid_claims={'sub': VAPID_SUBJECT},
            ttl=3600,
            timeout=10,
        )
        return 'sent'
    except WebPushException as e:
        status = getattr(e.response, 'status_code', None)
        if status in (404, 410):
            delete_subscription(sub['endpoint'])
            return 'removed'
        return 'failed'


class handler(BaseHTTPRequestHandler):
    def _respond(self, status, body):
        data = json.dumps(body).encode('utf-8')
        self.send_response(status)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_POST(self):
        provided = self.headers.get('X-Notify-Secret', '')
        if not NOTIFY_WEBHOOK_SECRET or not hmac.compare_digest(provided, NOTIFY_WEBHOOK_SECRET):
            self._respond(401, {'error': 'Tidak diizinkan'})
            return

        try:
            length = int(self.headers.get('Content-Length', 0))
            raw = self.rfile.read(length) if length else b'{}'
            body = json.loads(raw.decode('utf-8'))
        except Exception:
            body = {}

        now = datetime.now(WIB).strftime('%H:%M:%S')
        payload = {
            'title': body.get('title', 'NatunaPOS'),
            'body': body.get('body', f'Tes notifikasi pukul {now} WIB'),
            'url': '/push/',
        }

        counts = {'sent': 0, 'failed': 0, 'removed': 0}
        for sub in list_subscriptions():
            counts[send_one(sub, payload)] += 1
        self._respond(200, counts)
