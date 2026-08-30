#!/usr/bin/env bash
set -euo pipefail

BASE="${ZABISA_API_URL:-http://127.0.0.1:8088}"
PASSWORD="${ZABISA_DEV_PASSWORD:-ChangeMe123!}"
RUN="$(date +%s)"

login_token() {
  local email="$1" device="$2"
  curl -fsS "$BASE/api/v1/auth/login" \
    -H 'Content-Type: application/json' \
    -d "{\"email\":\"$email\",\"password\":\"$PASSWORD\",\"device_id\":\"$device\"}" \
  | python3 -c 'import json,sys; print(json.load(sys.stdin)["data"]["access_token"])'
}

data_id() { python3 -c 'import json,sys; print(json.load(sys.stdin)["data"]["id"])'; }

SUPER="$(login_token admin@zabisa.local phase36-super)"
USTADZ="$(login_token ustadz@zabisa.local phase36-ustadz)"
TEACHER="$(login_token teacher@zabisa.local phase36-teacher)"
DEMO_STUDENT="00000000-0000-4000-8000-000000000101"

echo "=== Phase 3.6 cross-service append-only audit ==="

STUDENT_NO="ZB-AUDIT-$RUN"
STUDENT="$(curl -fsS -X POST "$BASE/api/v1/admin/students" -H "Authorization: Bearer $SUPER" -H 'Content-Type: application/json' -H "X-Request-ID: phase36-student-create-$RUN" -d "{\"student_no\":\"$STUDENT_NO\",\"full_name\":\"DEVELOPMENT DATA Audit Student $RUN\",\"class_name\":\"Audit\",\"program_name\":\"Tahfidz\",\"academic_year\":\"2026/2027\"}")"
STUDENT_ID="$(printf '%s' "$STUDENT" | data_id)"
curl -fsS -X PATCH "$BASE/api/v1/admin/students/$STUDENT_ID" -H "Authorization: Bearer $SUPER" -H 'Content-Type: application/json' -H "X-Request-ID: phase36-student-update-$RUN" -d "{\"student_no\":\"$STUDENT_NO\",\"full_name\":\"DEVELOPMENT DATA Audit Student $RUN\",\"photo_url\":\"\",\"class_name\":\"Audit Updated\",\"program_name\":\"Tahfidz\",\"academic_year\":\"2026/2027\",\"status\":\"INACTIVE\"}" >/dev/null
echo "PASS student mutation fixtures"

echo "=== Guardian relationship audit fixture ==="
npm run phase35:guardian-verify

TAHFIDZ="$(curl -fsS -X POST "$BASE/api/v1/tahfidz/entries" -H "Authorization: Bearer $USTADZ" -H 'Content-Type: application/json' -H "X-Request-ID: phase36-tahfidz-$RUN" -d "{\"student_id\":\"$DEMO_STUDENT\",\"activity_date\":\"2026-08-30\",\"surah\":\"Al-Ikhlas\",\"ayah_start\":1,\"ayah_end\":4,\"juz\":30,\"page\":604,\"activity_type\":\"MURAJAAH\",\"score\":91,\"fluency\":\"BAIK\",\"tajwid\":\"BAIK\",\"makhraj\":\"BAIK\",\"teacher_note\":\"DEVELOPMENT DATA Phase 3.6 audit verification\"}")"
TAHFIDZ_ID="$(printf '%s' "$TAHFIDZ" | data_id)"
echo "PASS tahfidz mutation fixture: $TAHFIDZ_ID"

SUBJECT_ID="$(curl -fsS "$BASE/api/v1/admin/subjects" -H "Authorization: Bearer $TEACHER" | python3 -c 'import json,sys; rows=json.load(sys.stdin)["data"]; print(next(x["id"] for x in rows if x.get("active")))')"
GRADE="$(curl -fsS -X POST "$BASE/api/v1/grades" -H "Authorization: Bearer $TEACHER" -H 'Content-Type: application/json' -H "X-Request-ID: phase36-grade-create-$RUN" -d "{\"student_id\":\"$DEMO_STUDENT\",\"subject_id\":\"$SUBJECT_ID\",\"academic_year\":\"2026/2027\",\"semester\":\"1\",\"assessment_type\":\"PHASE36_AUDIT\",\"score\":93,\"grade\":\"A\",\"teacher_note\":\"DEVELOPMENT DATA audit\",\"published\":false}")"
GRADE_ID="$(printf '%s' "$GRADE" | data_id)"
curl -fsS -X PATCH "$BASE/api/v1/admin/grades/$GRADE_ID/publish" -H "Authorization: Bearer $TEACHER" -H "X-Request-ID: phase36-grade-publish-$RUN" >/dev/null
echo "PASS academic grade audit fixture"

SLUG="phase36-audit-$RUN"
CAMPAIGN="$(curl -fsS -X POST "$BASE/api/v1/admin/donation/campaigns" -H "Authorization: Bearer $SUPER" -H 'Content-Type: application/json' -H "X-Request-ID: phase36-campaign-create-$RUN" -d "{\"name\":\"DEVELOPMENT DATA Audit Campaign $RUN\",\"slug\":\"$SLUG\",\"description\":\"Phase 3.6 audit verification\",\"category\":\"Pendidikan Santri\",\"target_amount\":2000000,\"cover_url\":\"\",\"deadline\":null}")"
CAMPAIGN_ID="$(printf '%s' "$CAMPAIGN" | data_id)"
curl -fsS -X PATCH "$BASE/api/v1/admin/donation/campaigns/$CAMPAIGN_ID" -H "Authorization: Bearer $SUPER" -H 'Content-Type: application/json' -H "X-Request-ID: phase36-campaign-update-$RUN" -d "{\"name\":\"DEVELOPMENT DATA Audit Campaign $RUN\",\"slug\":\"$SLUG\",\"description\":\"Phase 3.6 audit verification\",\"category\":\"Pendidikan Santri\",\"target_amount\":2000000,\"cover_url\":\"\",\"deadline\":\"\",\"status\":\"PAUSED\"}" >/dev/null
echo "PASS donation campaign audit fixtures"

# Create a dedicated development donation so existing demo state is not consumed.
ACTIVE_CAMPAIGN="$(curl -fsS "$BASE/api/v1/donation/campaigns" | python3 -c 'import json,sys; rows=json.load(sys.stdin)["data"]; print(rows[0]["id"])')"
WAITING="$(curl -fsS -X POST "$BASE/api/v1/donations" -H 'Content-Type: application/json' -H "Idempotency-Key: phase36-audit-$RUN" -d "{\"campaign_id\":\"$ACTIVE_CAMPAIGN\",\"donor_name\":\"DEVELOPMENT DATA Audit Donor\",\"donor_email\":\"\",\"anonymous\":false,\"message\":\"Phase36\",\"amount\":10000,\"payment_method\":\"MANUAL_TRANSFER\"}")"
WAITING_ID="$(printf '%s' "$WAITING" | data_id)"
curl -fsS -X PATCH "$BASE/api/v1/admin/donations/$WAITING_ID/verify" -H "Authorization: Bearer $SUPER" -H "X-Request-ID: phase36-payment-verify-$RUN" >/dev/null
echo "PASS payment verification audit fixture"

expected='[
  ["STUDENT_CREATED","student-service"],
  ["STUDENT_UPDATED","student-service"],
  ["GUARDIAN_LINK_REQUESTED","student-service"],
  ["GUARDIAN_LINK_APPROVED","student-service"],
  ["GUARDIAN_LINK_REVOKED","student-service"],
  ["TAHFIDZ_ENTRY_CREATED","tahfidz-service"],
  ["GRADE_CREATED","academic-service"],
  ["GRADE_PUBLISHED","academic-service"],
  ["CAMPAIGN_CREATED","donation-service"],
  ["CAMPAIGN_UPDATED","donation-service"],
  ["PAYMENT_VERIFIED","donation-service"]
]'

for attempt in $(seq 1 20); do
  AUDIT_CHECK="/tmp/zabisa-audit-check.py"
  cat > "$AUDIT_CHECK" <<'PY_AUDIT_CHECK'
import json, sys
rows=json.load(sys.stdin).get('data',[])
expected=json.loads(sys.argv[1])
pairs={(r.get('action'),r.get('source_service')) for r in rows}
missing=[x for x in map(tuple,expected) if x not in pairs]
if missing:
    print('WAIT missing audit events:', missing)
    sys.exit(1)
for action,service in map(tuple,expected):
    row=next(r for r in rows if r.get('action')==action and r.get('source_service')==service)
    assert row.get('request_id'), (action,'missing request_id')
    assert row.get('trace_id'), (action,'missing trace_id')
print('PASS all cross-service audit actions delivered with request/trace correlation')
PY_AUDIT_CHECK
  if curl -fsS "$BASE/api/v1/admin/audit-logs" \
    -H "Authorization: Bearer $SUPER" \
    | python3 "$AUDIT_CHECK" "$expected"
  then
    break
  fi
  if [ "$attempt" = 20 ]; then
    echo "FAIL audit delivery timeout"
    exit 1
  fi
  sleep 2
done


MUTATE_AUDIT_CODE="$(curl -sS -o /tmp/zabisa-phase36-audit-mutate.txt -w '%{http_code}' -X DELETE "$BASE/api/v1/admin/audit-logs/not-allowed" -H "Authorization: Bearer $SUPER")"
if [ "$MUTATE_AUDIT_CODE" != "404" ] && [ "$MUTATE_AUDIT_CODE" != "405" ]; then
  echo "FAIL audit append-only API invariant: DELETE returned HTTP $MUTATE_AUDIT_CODE"
  cat /tmp/zabisa-phase36-audit-mutate.txt
  exit 1
fi
echo "PASS audit read model has no normal-admin mutation endpoint"

echo "=== PHASE 3.6 AUDIT: PASS ==="
