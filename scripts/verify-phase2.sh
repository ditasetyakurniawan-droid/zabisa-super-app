#!/usr/bin/env bash
set -euo pipefail
BASE="${ZABISA_API_URL:-http://localhost:8088}"
for _ in $(seq 1 45); do curl -fsS "$BASE/health/live" >/dev/null && break; sleep 2; done
curl -fsS "$BASE/health/live" >/dev/null || { echo 'API gateway not ready'; exit 1; }
ADMIN_JSON=$(curl -fsS -X POST "$BASE/api/v1/auth/login" -H 'Content-Type: application/json' -d '{"email":"admin@zabisa.local","password":"ChangeMe123!","device_id":"verify-admin"}')
ADMIN_TOKEN=$(printf '%s' "$ADMIN_JSON" | python3 -c 'import json,sys; print(json.load(sys.stdin)["data"]["access_token"])')
GUARDIAN_JSON=$(curl -fsS -X POST "$BASE/api/v1/auth/login" -H 'Content-Type: application/json' -d '{"email":"guardian@zabisa.local","password":"ChangeMe123!","device_id":"verify-guardian"}')
GUARDIAN_TOKEN=$(printf '%s' "$GUARDIAN_JSON" | python3 -c 'import json,sys; print(json.load(sys.stdin)["data"]["access_token"])')
STUDENTS=$(curl -fsS "$BASE/api/v1/guardian/students" -H "Authorization: Bearer $GUARDIAN_TOKEN")
STUDENT_ID=$(printf '%s' "$STUDENTS" | python3 -c 'import json,sys; x=json.load(sys.stdin)["data"]; assert x, "guardian demo has no linked student"; print(x[0]["id"])')
STAMP=$(date +%s)
START=$(date -u -d '+1 day' +'%Y-%m-%dT%H:%M:%SZ')
curl -fsS -X POST "$BASE/api/v1/admin/kajian" -H "Authorization: Bearer $ADMIN_TOKEN" -H 'Content-Type: application/json' -d "{\"title\":\"Kajian E2E $STAMP\",\"slug\":\"kajian-e2e-$STAMP\",\"description\":\"Automated local vertical-slice verification\",\"speaker\":\"Ustadz Demo\",\"start_at\":\"$START\",\"location\":\"Zabisa Temanggung\",\"published\":true}" >/dev/null
TODAY=$(date +%F)
curl -fsS -X POST "$BASE/api/v1/tahfidz/entries" -H "Authorization: Bearer $ADMIN_TOKEN" -H 'Content-Type: application/json' -d "{\"student_id\":\"$STUDENT_ID\",\"activity_date\":\"$TODAY\",\"surah\":\"Al-Fatihah\",\"ayah_start\":1,\"ayah_end\":7,\"activity_type\":\"MURAJAAH\",\"teacher_note\":\"Automated E2E verification\"}" >/dev/null
sleep 5
NOTIFICATIONS=$(curl -fsS "$BASE/api/v1/notifications" -H "Authorization: Bearer $GUARDIAN_TOKEN")
printf '%s' "$NOTIFICATIONS" | python3 -c 'import json,sys; data=json.load(sys.stdin)["data"]; types={x.get("type") for x in data}; assert "TAHFIDZ" in types, f"TAHFIDZ notification missing: {types}"; assert "KAJIAN" in types, f"KAJIAN notification missing: {types}"; print("E2E OK: Admin Login -> Kajian -> Outbox -> Notification Inbox"); print("E2E OK: Guardian Login -> Linked Student -> Tahfidz -> Outbox -> Guardian Notification")'
echo "Student demo: $STUDENT_ID"
echo "Backoffice: http://localhost:3001"
echo "API: $BASE"
