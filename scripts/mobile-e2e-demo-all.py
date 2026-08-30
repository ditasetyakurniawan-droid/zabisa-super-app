#!/usr/bin/env python3
"""Acceptance check for the Phase 3.3 localhost development dataset."""
from __future__ import annotations

import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request

BASE = os.getenv('ZABISA_API_URL', 'http://127.0.0.1:8088').rstrip('/')
PASSWORD = os.getenv('ZABISA_DEMO_PASSWORD', 'ChangeMe123!')
parsed = urllib.parse.urlparse(BASE)
if parsed.scheme != 'http' or parsed.hostname not in {'127.0.0.1', 'localhost', '::1'}:
    raise SystemExit(f'REFUSED: demo verification may only target localhost. BASE={BASE}')


def call(path: str, token: str | None = None):
    headers = {'Accept': 'application/json'}
    if token:
        headers['Authorization'] = f'Bearer {token}'
    req = urllib.request.Request(BASE + path, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=15) as response:
            raw = response.read()
    except urllib.error.HTTPError as exc:
        raise RuntimeError(f'GET {path}: HTTP {exc.code}: {exc.read().decode(errors="replace")[:800]}') from exc
    body = json.loads(raw) if raw else None
    if isinstance(body, dict) and body.get('error'):
        raise RuntimeError(f'GET {path}: {body["error"]}')
    return body.get('data') if isinstance(body, dict) and 'data' in body else body


def post(path: str, data: dict):
    req = urllib.request.Request(BASE + path, data=json.dumps(data).encode(), method='POST', headers={'Accept': 'application/json', 'Content-Type': 'application/json'})
    with urllib.request.urlopen(req, timeout=15) as response:
        body = json.loads(response.read())
    return body['data']


def require(name: str, actual: int, minimum: int):
    if actual < minimum:
        print(f'FAIL {name}: expected >= {minimum}, got {actual}')
        return False
    print(f'PASS {name}: {actual}')
    return True


def main() -> int:
    print('=== Zabisa Phase 3.3 FULL DEMO E2E ===')
    call('/health/live')
    session = post('/api/v1/auth/login', {'email': 'guardian@zabisa.local', 'password': PASSWORD, 'device_id': 'phase33-e2e'})
    token = session['access_token']

    checks: list[bool] = []
    public_specs = [
        ('published kajian', '/api/v1/kajian', 3),
        ('news', '/api/v1/content?type=NEWS', 3),
        ('programs', '/api/v1/content?type=PROGRAM', 3),
        ('profiles', '/api/v1/content?type=PROFILE', 2),
        ('gallery metadata', '/api/v1/content?type=GALLERY', 3),
        ('active campaigns', '/api/v1/donation/campaigns', 3),
        ('payment methods', '/api/v1/donation/payment-methods', 2),
    ]
    for name, path, minimum in public_specs:
        checks.append(require(name, len(call(path) or []), minimum))

    campaigns = call('/api/v1/donation/campaigns') or []
    if campaigns:
        total_updates = 0
        campaigns_with_updates = 0
        for campaign in campaigns:
            updates = call(f"/api/v1/donation/campaigns/{campaign['id']}/updates") or []
            if updates:
                campaigns_with_updates += 1
                total_updates += len(updates)
        checks.append(require('campaign updates', total_updates, 1))
        print(f'INFO campaign updates found across {campaigns_with_updates} active campaign(s)')

    students = call('/api/v1/guardian/students', token) or []
    checks.append(require('guardian linked students', len(students), 2))
    for student in students[:2]:
        sid = student['id']
        label = student.get('full_name') or sid
        checks.append(require(f'{label} tahfidz', len(call(f'/api/v1/tahfidz/students/{sid}/entries', token) or []), 2))
        checks.append(require(f'{label} grades', len(call(f'/api/v1/students/{sid}/grades', token) or []), 5))
        checks.append(require(f'{label} attendance', len(call(f'/api/v1/guardian/students/{sid}/attendance', token) or []), 7))
        checks.append(require(f'{label} reports', len(call(f'/api/v1/students/{sid}/reports', token) or []), 2))

    history = call('/api/v1/donations/history', token) or []
    checks.append(require('guardian donation history', len(history), 3))
    statuses = {str(item.get('status', '')).upper() for item in history}
    paid_ok = 'PAID' in statuses
    pending_ok = bool({'WAITING_PAYMENT', 'PENDING'} & statuses)
    print(('PASS' if paid_ok else 'FAIL') + f' donation paid state: {sorted(statuses)}')
    print(('PASS' if pending_ok else 'FAIL') + f' donation waiting state: {sorted(statuses)}')
    checks.extend([paid_ok, pending_ok])

    notifications = call('/api/v1/notifications', token) or []
    checks.append(require('guardian notifications', len(notifications), 6))

    if all(checks):
        print('=== RESULT: PASS ===')
        print('Public content, donations, multi-student guardian data, tahfidz, academic, attendance, reports and notifications are populated through real APIs.')
        return 0
    print('=== RESULT: FAIL ===')
    return 1


if __name__ == '__main__':
    try:
        raise SystemExit(main())
    except Exception as exc:  # noqa: BLE001 - diagnostic CLI
        print(f'E2E FAILED: {exc}', file=sys.stderr)
        raise SystemExit(1)
