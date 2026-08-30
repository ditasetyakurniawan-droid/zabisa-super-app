#!/usr/bin/env bash
set -euo pipefail
BASE="${ZABISA_API_URL:-http://127.0.0.1:8088}"
PASS="${ZABISA_DEV_PASSWORD:-ChangeMe123!}"
RUN="$(date +%s)"
TMP="/tmp/zabisa-phase37-audit"
mkdir -p "$TMP"

login(){ local email="$1" device="$2"; curl -fsS "$BASE/api/v1/auth/login" -H 'Content-Type: application/json' -d "{\"email\":\"$email\",\"password\":\"$PASS\",\"device_id\":\"$device\"}" | python3 -c 'import json,sys; print(json.load(sys.stdin)["data"]["access_token"])'; }
data_id(){ python3 -c 'import json,sys; print(json.load(sys.stdin)["data"]["id"])'; }
req(){ local token="$1" method="$2" path="$3" rid="$4" body="${5:-}"; if [ -n "$body" ]; then curl -fsS -X "$method" "$BASE$path" -H "Authorization: Bearer $token" -H 'Content-Type: application/json' -H "X-Request-ID: $rid" -d "$body"; else curl -fsS -X "$method" "$BASE$path" -H "Authorization: Bearer $token" -H "X-Request-ID: $rid"; fi; }

SUPER="$(login admin@zabisa.local phase37-audit-super)"
GUARDIAN="$(login guardian@zabisa.local phase37-audit-guardian)"
GUARDIAN_ID="$(curl -fsS "$BASE/api/v1/auth/me" -H "Authorization: Bearer $GUARDIAN" | python3 -c 'import json,sys; print(json.load(sys.stdin)["data"]["id"])')"
DEMO_STUDENT="${ZABISA_STUDENT_ID:-00000000-0000-4000-8000-000000000101}"

echo '=== Phase 3.7 extended append-only audit coverage ==='

# Student + attendance.
STUDENT_NO="P37AUD-$RUN"
STUDENT="$(req "$SUPER" POST /api/v1/admin/students "p37-student-create-$RUN" "{\"student_no\":\"$STUDENT_NO\",\"full_name\":\"DEVELOPMENT DATA P37 Audit Student $RUN\",\"photo_url\":\"\",\"class_name\":\"Audit A\",\"program_name\":\"Tahfidz\",\"academic_year\":\"2026/2027\",\"status\":\"ACTIVE\"}")"
STUDENT_ID="$(printf '%s' "$STUDENT" | data_id)"
req "$SUPER" POST /api/v1/admin/attendance "p37-attendance-$RUN" "{\"student_id\":\"$STUDENT_ID\",\"date\":\"2026-08-31\",\"status\":\"PRESENT\",\"note\":\"DEVELOPMENT DATA P37 audit\"}" >/dev/null

# Guardian request + approve + revoke on the development student.
LINK="$(req "$SUPER" POST /api/v1/admin/guardian-links "p37-guardian-request-$RUN" "{\"guardian_user_id\":\"$GUARDIAN_ID\",\"student_id\":\"$STUDENT_ID\",\"relationship\":\"GUARDIAN\"}")"
LINK_ID="$(printf '%s' "$LINK" | data_id)"
req "$SUPER" PATCH "/api/v1/admin/guardian-links/$LINK_ID/approve" "p37-guardian-approve-$RUN" >/dev/null
req "$SUPER" PATCH "/api/v1/admin/guardian-links/$LINK_ID/revoke" "p37-guardian-revoke-$RUN" >/dev/null

# Tahfidz target create/update.
TARGET="$(req "$SUPER" POST /api/v1/tahfidz/targets "p37-target-create-$RUN" "{\"student_id\":\"$STUDENT_ID\",\"target_juz\":1.25,\"target_date\":\"2026-12-31\"}")"
TARGET_ID="$(printf '%s' "$TARGET" | data_id)"
req "$SUPER" PATCH "/api/v1/tahfidz/targets/$TARGET_ID" "p37-target-update-$RUN" '{"target_juz":2.25,"target_date":"2027-01-31"}' >/dev/null

# Subject + report lifecycle.
SUBJECT_CODE="P37A$RUN"
SUBJECT="$(req "$SUPER" POST /api/v1/admin/subjects "p37-subject-create-$RUN" "{\"code\":\"$SUBJECT_CODE\",\"name\":\"DEVELOPMENT DATA P37 Subject $RUN\",\"category\":\"ACADEMIC\"}")"
SUBJECT_ID="$(printf '%s' "$SUBJECT" | data_id)"
req "$SUPER" PATCH "/api/v1/admin/subjects/$SUBJECT_ID" "p37-subject-update-$RUN" "{\"code\":\"$SUBJECT_CODE\",\"name\":\"DEVELOPMENT DATA P37 Subject Updated $RUN\",\"category\":\"RELIGIOUS\",\"active\":true}" >/dev/null
REPORT="$(req "$SUPER" POST /api/v1/admin/reports "p37-report-create-$RUN" "{\"student_id\":\"$DEMO_STUDENT\",\"academic_year\":\"2026/2027\",\"semester\":\"1\",\"report_type\":\"P37_AUDIT_$RUN\"}")"
REPORT_ID="$(printf '%s' "$REPORT" | data_id)"
req "$SUPER" PATCH "/api/v1/admin/reports/$REPORT_ID/publish" "p37-report-publish-$RUN" >/dev/null

# Payment method + campaign update.
METHOD_CODE="P37AUD$RUN"
METHOD="$(req "$SUPER" POST /api/v1/admin/donation/payment-methods "p37-method-create-$RUN" "{\"method_code\":\"$METHOD_CODE\",\"display_name\":\"DEVELOPMENT DATA P37 Method\",\"bank_name\":\"Demo Bank\",\"account_number\":\"37$RUN\",\"account_holder\":\"Zabisa Development\",\"instructions\":\"Audit fixture\"}")"
METHOD_ID="$(printf '%s' "$METHOD" | data_id)"
req "$SUPER" PATCH "/api/v1/admin/donation/payment-methods/$METHOD_ID" "p37-method-update-$RUN" "{\"method_code\":\"$METHOD_CODE\",\"display_name\":\"DEVELOPMENT DATA P37 Method\",\"bank_name\":\"Demo Bank\",\"account_number\":\"37$RUN\",\"account_holder\":\"Zabisa Development\",\"instructions\":\"Audit fixture\",\"active\":false}" >/dev/null
SLUG="p37-audit-$RUN"
CAMPAIGN="$(req "$SUPER" POST /api/v1/admin/donation/campaigns "p37-campaign-create-$RUN" "{\"name\":\"DEVELOPMENT DATA P37 Campaign $RUN\",\"slug\":\"$SLUG\",\"description\":\"P37 audit fixture\",\"category\":\"Pendidikan Santri\",\"target_amount\":1000000,\"cover_url\":\"\",\"deadline\":null}")"
CAMPAIGN_ID="$(printf '%s' "$CAMPAIGN" | data_id)"
req "$SUPER" POST "/api/v1/admin/donation/campaigns/$CAMPAIGN_ID/updates" "p37-campaign-update-post-$RUN" "{\"title\":\"DEVELOPMENT DATA P37 Update\",\"body\":\"Audit coverage fixture\"}" >/dev/null
req "$SUPER" PATCH "/api/v1/admin/donation/campaigns/$CAMPAIGN_ID" "p37-campaign-update-$RUN" "{\"name\":\"DEVELOPMENT DATA P37 Campaign $RUN\",\"slug\":\"$SLUG\",\"description\":\"P37 audit fixture\",\"category\":\"Pendidikan Santri\",\"target_amount\":1000000,\"cover_url\":\"\",\"deadline\":\"\",\"status\":\"ARCHIVED\"}" >/dev/null

# Content + kajian.
CONTENT_SLUG="p37-news-$RUN"
CONTENT="$(req "$SUPER" POST /api/v1/admin/content "p37-content-create-$RUN" "{\"type\":\"NEWS\",\"title\":\"DEVELOPMENT DATA P37 News $RUN\",\"slug\":\"$CONTENT_SLUG\",\"summary\":\"Audit fixture\",\"body\":\"Audit fixture body\",\"image_url\":\"\",\"published\":false}")"
CONTENT_ID="$(printf '%s' "$CONTENT" | data_id)"
req "$SUPER" PATCH "/api/v1/admin/content/$CONTENT_ID" "p37-content-update-$RUN" "{\"type\":\"NEWS\",\"title\":\"DEVELOPMENT DATA P37 News Updated $RUN\",\"slug\":\"$CONTENT_SLUG\",\"summary\":\"Audit fixture updated\",\"body\":\"Audit fixture body\",\"image_url\":\"\",\"published\":false}" >/dev/null
KAJIAN_SLUG="p37-kajian-$RUN"
START="2026-12-31T12:00:00Z"
KAJIAN="$(req "$SUPER" POST /api/v1/admin/kajian "p37-kajian-create-$RUN" "{\"title\":\"DEVELOPMENT DATA P37 Kajian $RUN\",\"slug\":\"$KAJIAN_SLUG\",\"description\":\"P37 audit fixture\",\"speaker\":\"Ustadz Demo\",\"start_at\":\"$START\",\"end_at\":null,\"location\":\"Masjid Demo\",\"map_url\":\"\",\"live_url\":\"\",\"poster_url\":\"\",\"published\":false}")"
KAJIAN_ID="$(printf '%s' "$KAJIAN" | data_id)"
req "$SUPER" PATCH "/api/v1/admin/kajian/$KAJIAN_ID" "p37-kajian-update-$RUN" "{\"title\":\"DEVELOPMENT DATA P37 Kajian Updated $RUN\",\"slug\":\"$KAJIAN_SLUG\",\"description\":\"P37 audit fixture updated\",\"speaker\":\"Ustadz Demo\",\"start_at\":\"$START\",\"end_at\":null,\"location\":\"Masjid Demo\",\"map_url\":\"\",\"live_url\":\"\",\"poster_url\":\"\",\"published\":false}" >/dev/null

# Notification immediate + scheduled.
req "$SUPER" POST /api/v1/admin/notifications "p37-notification-create-$RUN" "{\"user_id\":\"$GUARDIAN_ID\",\"type\":\"ANNOUNCEMENT\",\"title\":\"DEVELOPMENT DATA P37 Immediate $RUN\",\"message\":\"Audit fixture\",\"deep_link\":\"zabisa://notifications\",\"scheduled_at\":\"\"}" >/dev/null
req "$SUPER" POST /api/v1/admin/notifications "p37-notification-scheduled-$RUN" "{\"user_id\":\"$GUARDIAN_ID\",\"type\":\"ANNOUNCEMENT\",\"title\":\"DEVELOPMENT DATA P37 Scheduled $RUN\",\"message\":\"Audit fixture\",\"deep_link\":\"zabisa://notifications\",\"scheduled_at\":\"2027-01-01T00:00:00Z\"}" >/dev/null

expected='[
 ["ATTENDANCE_UPSERTED","student-service"],
 ["TAHFIDZ_TARGET_CREATED","tahfidz-service"],
 ["TAHFIDZ_TARGET_UPDATED","tahfidz-service"],
 ["SUBJECT_CREATED","academic-service"],
 ["SUBJECT_UPDATED","academic-service"],
 ["REPORT_CREATED","academic-service"],
 ["REPORT_PUBLISHED","academic-service"],
 ["PAYMENT_METHOD_CREATED","donation-service"],
 ["PAYMENT_METHOD_UPDATED","donation-service"],
 ["CAMPAIGN_UPDATE_CREATED","donation-service"],
 ["CONTENT_CREATED","content-service"],
 ["CONTENT_UPDATED","content-service"],
 ["KAJIAN_CREATED","content-service"],
 ["KAJIAN_UPDATED","content-service"],
 ["NOTIFICATION_CREATED","notification-service"],
 ["NOTIFICATION_SCHEDULED","notification-service"]
]'

for attempt in $(seq 1 30); do
  AUDIT_CHECK="/tmp/zabisa-audit-check.py"
  cat > "$AUDIT_CHECK" <<'PY_AUDIT_CHECK'
import json, sys
rows=json.load(sys.stdin).get('data',[])
expected=[tuple(x) for x in json.loads(sys.argv[1])]
pairs={(r.get('action'),r.get('source_service')) for r in rows}
missing=[x for x in expected if x not in pairs]
if missing:
    print('WAIT missing Phase 3.7 audit events:',missing)
    sys.exit(1)
for action,service in expected:
    row=next(r for r in rows if r.get('action')==action and r.get('source_service')==service)
    assert row.get('request_id'), (action,'missing request_id')
    assert row.get('trace_id'), (action,'missing trace_id')
print('PASS extended sensitive-mutation audit coverage with correlation')
PY_AUDIT_CHECK
  if curl -fsS "$BASE/api/v1/admin/audit-logs" \
    -H "Authorization: Bearer $SUPER" \
    | python3 "$AUDIT_CHECK" "$expected"
  then break; fi
  if [ "$attempt" = 30 ]; then echo 'FAIL Phase 3.7 audit delivery timeout'; exit 1; fi
  sleep 2
done

# Lifecycle cleanup, not destructive delete.
req "$SUPER" PATCH "/api/v1/admin/students/$STUDENT_ID" "p37-student-cleanup-$RUN" "{\"student_no\":\"$STUDENT_NO\",\"full_name\":\"DEVELOPMENT DATA P37 Audit Student $RUN\",\"photo_url\":\"\",\"class_name\":\"Audit A\",\"program_name\":\"Tahfidz\",\"academic_year\":\"2026/2027\",\"status\":\"INACTIVE\"}" >/dev/null
req "$SUPER" PATCH "/api/v1/admin/subjects/$SUBJECT_ID" "p37-subject-cleanup-$RUN" "{\"code\":\"$SUBJECT_CODE\",\"name\":\"DEVELOPMENT DATA P37 Subject Updated $RUN\",\"category\":\"RELIGIOUS\",\"active\":false}" >/dev/null

echo '=== PHASE 3.7 AUDIT COVERAGE: PASS ==='
