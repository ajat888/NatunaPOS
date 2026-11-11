import os
import json
import hashlib
import time
import requests

SUPABASE_URL = os.environ.get('SUPABASE_URL', '').rstrip('/')
SUPABASE_ANON_KEY = os.environ.get('SUPABASE_ANON_KEY', '')
SUPABASE_SERVICE_KEY = os.environ.get('SUPABASE_SERVICE_KEY', '')

PIN_LENGTH = 6
MAX_ATTEMPTS = 5
LOCK_DURATION_MS = 60 * 60 * 1000  # 1 jam


def verify_jwt(jwt):
    if not jwt:
        return None
    try:
        r = requests.get(
            f'{SUPABASE_URL}/auth/v1/user',
            headers={
                'apikey': SUPABASE_ANON_KEY,
                'Authorization': f'Bearer {jwt}',
            },
            timeout=10,
        )
        if r.status_code != 200:
            return None
        return r.json().get('id')
    except Exception:
        return None


def hash_pin(pin, salt):
    return hashlib.sha256(f'{salt}{pin}{salt}'.encode('utf-8')).hexdigest()


def generate_salt():
    return os.urandom(16).hex()


def validate_pin(pin):
    if not isinstance(pin, str):
        return False
    if len(pin) != PIN_LENGTH:
        return False
    return pin.isdigit()


def get_pin_row(uid):
    try:
        r = requests.get(
            f'{SUPABASE_URL}/rest/v1/owner_pins',
            params={'user_id': f'eq.{uid}', 'select': '*'},
            headers={
                'apikey': SUPABASE_SERVICE_KEY,
                'Authorization': f'Bearer {SUPABASE_SERVICE_KEY}',
            },
            timeout=10,
        )
        if r.status_code != 200:
            return None
        rows = r.json()
        return rows[0] if rows else None
    except Exception:
        return None


def upsert_pin_row(uid, pin_hash, salt):
    headers = {
        'apikey': SUPABASE_SERVICE_KEY,
        'Authorization': f'Bearer {SUPABASE_SERVICE_KEY}',
        'Content-Type': 'application/json',
        'Prefer': 'resolution=merge-duplicates',
    }
    payload = {
        'user_id': uid,
        'pin_hash': pin_hash,
        'salt': salt,
        'failed_attempts': 0,
        'locked_until_ms': 0,
        'updated_at': time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime()),
    }
    r = requests.post(
        f'{SUPABASE_URL}/rest/v1/owner_pins',
        headers=headers,
        data=json.dumps(payload),
        timeout=10,
    )
    return r.status_code in (200, 201, 204)


def patch_pin_row(uid, updates):
    headers = {
        'apikey': SUPABASE_SERVICE_KEY,
        'Authorization': f'Bearer {SUPABASE_SERVICE_KEY}',
        'Content-Type': 'application/json',
    }
    r = requests.patch(
        f'{SUPABASE_URL}/rest/v1/owner_pins',
        params={'user_id': f'eq.{uid}'},
        headers=headers,
        data=json.dumps(updates),
        timeout=10,
    )
    return r.status_code in (200, 204)


def delete_pin_row(uid):
    r = requests.delete(
        f'{SUPABASE_URL}/rest/v1/owner_pins',
        params={'user_id': f'eq.{uid}'},
        headers={
            'apikey': SUPABASE_SERVICE_KEY,
            'Authorization': f'Bearer {SUPABASE_SERVICE_KEY}',
        },
        timeout=10,
    )
    return r.status_code in (200, 204)


def verify_supabase_credentials(email, password):
    try:
        r = requests.post(
            f'{SUPABASE_URL}/auth/v1/token',
            params={'grant_type': 'password'},
            headers={
                'apikey': SUPABASE_ANON_KEY,
                'Content-Type': 'application/json',
            },
            json={'email': email, 'password': password},
            timeout=15,
        )
        if r.status_code != 200:
            return None
        data = r.json()
        return data.get('user', {}).get('id')
    except Exception:
        return None


def verify_pin(uid, pin):
    row = get_pin_row(uid)
    if not row:
        return {'valid': False, 'reason': 'no_pin'}
    now = int(time.time() * 1000)
    locked = int(row.get('locked_until_ms', 0) or 0)
    if locked > now:
        return {'valid': False, 'reason': 'locked', 'locked_until_ms': locked}
    expected = hash_pin(pin, row.get('salt', ''))
    if expected == row.get('pin_hash', ''):
        patch_pin_row(uid, {'failed_attempts': 0, 'locked_until_ms': 0})
        return {'valid': True}
    attempts = int(row.get('failed_attempts', 0) or 0) + 1
    updates = {'failed_attempts': attempts}
    new_locked = locked
    if attempts >= MAX_ATTEMPTS:
        new_locked = now + LOCK_DURATION_MS
        updates['locked_until_ms'] = new_locked
        updates['failed_attempts'] = 0
    patch_pin_row(uid, updates)
    return {
        'valid': False,
        'reason': 'wrong',
        'locked_until_ms': new_locked,
        'failed_attempts': attempts if new_locked == locked else 0,
    }