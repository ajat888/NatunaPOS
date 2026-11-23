import json
from http.server import BaseHTTPRequestHandler
import os
from api._shared import SUPABASE_URL, SUPABASE_ANON_KEY

VAPID_PUBLIC_KEY = os.environ.get('VAPID_PUBLIC_KEY', '')


class handler(BaseHTTPRequestHandler):
    def do_GET(self):
        data = json.dumps({
            'supabase_url': SUPABASE_URL,
            'supabase_anon_key': SUPABASE_ANON_KEY,
            'vapid_public_key': VAPID_PUBLIC_KEY,
        }).encode('utf-8')
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(data)))
        self.send_header('Access-Control-Allow-Origin', '*')
        self.end_headers()
        self.wfile.write(data)
