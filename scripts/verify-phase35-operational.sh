#!/usr/bin/env bash
set -euo pipefail
BASE=${ZABISA_API_URL:-http://127.0.0.1:8088}
PASS=${ZABISA_DEV_PASSWORD:-ChangeMe123!}
DEMO_STUDENT=${ZABISA_STUDENT_ID:-00000000-0000-4000-8000-000000000101}
TMP=/tmp/zabisa-phase35
mkdir -p "$TMP"

login(){ local email=$1; curl -fsS "$BASE/api/v1/auth/login" -H 'Content-Type: application/json' -d "{\"email\":\"$email\",\"password\":\"$PASS\",\"device_id\":\"phase35-operational\"}" | python3 -c 'import json,sys; print(json.load(sys.stdin)["data"]["access_token"])'; }
data_id(){ python3 -c 'import json,sys; print(json.load(sys.stdin)["data"]["id"])'; }
json_count(){ python3 -c 'import json,sys; print(len(json.load(sys.stdin).get("data",[])))'; }
status(){ local token=$1 method=$2 path=$3 body=${4:-}; if [[ -n "$body" ]]; then curl -sS -o "$TMP/body.json" -w '%{http_code}' -X "$method" "$BASE$path" -H "Authorization: Bearer $token" -H 'Content-Type: application/json' -d "$body"; else curl -sS -o "$TMP/body.json" -w '%{http_code}' -X "$method" "$BASE$path" -H "Authorization: Bearer $token"; fi; }
expect_code(){ local label=$1 got=$2 want=$3; if [[ "$got" != "$want" ]]; then echo "FAIL $label: HTTP $got expected $want"; cat "$TMP/body.json" 2>/dev/null || true; exit 1; fi; echo "PASS $label: HTTP $got"; }
contains_id(){ local id=$1; python3 -c 'import json,sys; i=sys.argv[1]; rows=json.load(sys.stdin).get("data",[]); raise SystemExit(0 if any(str(x.get("id"))==i for x in rows) else 1)' "$id"; }

SUPER=$(login admin@zabisa.local)
GUARDIAN=$(login guardian@zabisa.local)
GUARDIAN_ID=$(curl -fsS "$BASE/api/v1/auth/me" -H "Authorization: Bearer $GUARDIAN" | python3 -c 'import json,sys; print(json.load(sys.stdin)["data"]["id"])')
STAMP=$(date +%s)
STUDENT_NO="P35-$STAMP"

echo '=== Phase 3.5 Operational Backoffice integration ==='

# Student create -> update lifecycle.
CREATE=$(curl -fsS -X POST "$BASE/api/v1/admin/students" -H "Authorization: Bearer $SUPER" -H 'Content-Type: application/json' -d "{\"student_no\":\"$STUDENT_NO\",\"full_name\":\"DEVELOPMENT DATA Phase35 Student $STAMP\",\"class_name\":\"Demo A\",\"program_name\":\"Tahfidz\",\"academic_year\":\"2026/2027\"}")
STUDENT_ID=$(printf '%s' "$CREATE" | data_id)
expect_code 'student update' "$(status "$SUPER" PATCH "/api/v1/admin/students/$STUDENT_ID" "{\"student_no\":\"$STUDENT_NO\",\"full_name\":\"DEVELOPMENT DATA Phase35 Student Updated $STAMP\",\"photo_url\":\"\",\"class_name\":\"Demo B\",\"program_name\":\"Tahfidz Intensif\",\"academic_year\":\"2026/2027\",\"status\":\"ACTIVE\"}")" 200
curl -fsS "$BASE/api/v1/admin/students?q=$STUDENT_NO" -H "Authorization: Bearer $SUPER" | python3 -c 'import json,sys; sid=sys.argv[1]; rows=json.load(sys.stdin)["data"]; r=next((x for x in rows if x["id"]==sid),None); assert r and r["class_name"]=="Demo B" and r["status"]=="ACTIVE"; print("PASS student create/update/read")' "$STUDENT_ID"

# Object-level authorization must deny unrelated guardian before linking.
expect_code 'unlinked guardian grade read denied' "$(status "$GUARDIAN" GET "/api/v1/students/$STUDENT_ID/grades")" 403
expect_code 'unlinked guardian tahfidz read denied' "$(status "$GUARDIAN" GET "/api/v1/tahfidz/students/$STUDENT_ID/entries")" 403
expect_code 'unlinked guardian report read denied' "$(status "$GUARDIAN" GET "/api/v1/students/$STUDENT_ID/reports")" 403

# Guardian relationship approval and revocation changes object-level access.
LINK=$(curl -fsS -X POST "$BASE/api/v1/admin/guardian-links" -H "Authorization: Bearer $SUPER" -H 'Content-Type: application/json' -d "{\"guardian_user_id\":\"$GUARDIAN_ID\",\"student_id\":\"$STUDENT_ID\",\"relationship\":\"GUARDIAN\"}")
LINK_ID=$(printf '%s' "$LINK" | data_id)
expect_code 'guardian link approve' "$(status "$SUPER" PATCH "/api/v1/admin/guardian-links/$LINK_ID/approve")" 200
expect_code 'linked guardian grade read allowed' "$(status "$GUARDIAN" GET "/api/v1/students/$STUDENT_ID/grades")" 200
expect_code 'guardian link revoke' "$(status "$SUPER" PATCH "/api/v1/admin/guardian-links/$LINK_ID/revoke")" 200
expect_code 'revoked guardian grade read denied' "$(status "$GUARDIAN" GET "/api/v1/students/$STUDENT_ID/grades")" 403

# Attendance is an operational upsert, not destructive CRUD.
TODAY=$(date +%F)
expect_code 'attendance create/upsert' "$(status "$SUPER" POST /api/v1/admin/attendance "{\"student_id\":\"$STUDENT_ID\",\"date\":\"$TODAY\",\"status\":\"PRESENT\",\"note\":\"DEVELOPMENT DATA Phase35\"}")" 200
expect_code 'attendance update by natural key' "$(status "$SUPER" POST /api/v1/admin/attendance "{\"student_id\":\"$STUDENT_ID\",\"date\":\"$TODAY\",\"status\":\"PERMITTED\",\"note\":\"DEVELOPMENT DATA updated\"}")" 200
curl -fsS "$BASE/api/v1/admin/attendance?student_id=$STUDENT_ID" -H "Authorization: Bearer $SUPER" | python3 -c 'import json,sys; rows=json.load(sys.stdin)["data"]; assert rows and rows[0]["status"]=="PERMITTED"; print("PASS attendance operational upsert")'

# Tahfidz target create -> update.
TARGET=$(curl -fsS -X POST "$BASE/api/v1/tahfidz/targets" -H "Authorization: Bearer $SUPER" -H 'Content-Type: application/json' -d "{\"student_id\":\"$STUDENT_ID\",\"target_juz\":1.5,\"target_date\":\"2026-12-31\"}")
TARGET_ID=$(printf '%s' "$TARGET" | data_id)
expect_code 'tahfidz target update' "$(status "$SUPER" PATCH "/api/v1/tahfidz/targets/$TARGET_ID" '{"target_juz":2.5,"target_date":"2027-01-31"}')" 200
curl -fsS "$BASE/api/v1/tahfidz/targets?student_id=$STUDENT_ID" -H "Authorization: Bearer $SUPER" | python3 -c 'import json,sys; tid=sys.argv[1]; rows=json.load(sys.stdin)["data"]; r=next((x for x in rows if x["id"]==tid),None); assert r and abs(float(r["target_juz"])-2.5)<0.001; print("PASS tahfidz target create/update")' "$TARGET_ID"

# Subject create -> update and active lifecycle.
SUBJECT_CODE="P35-$STAMP"
SUBJECT=$(curl -fsS -X POST "$BASE/api/v1/admin/subjects" -H "Authorization: Bearer $SUPER" -H 'Content-Type: application/json' -d "{\"code\":\"$SUBJECT_CODE\",\"name\":\"DEVELOPMENT DATA Subject $STAMP\",\"category\":\"ACADEMIC\"}")
SUBJECT_ID=$(printf '%s' "$SUBJECT" | data_id)
expect_code 'subject update' "$(status "$SUPER" PATCH "/api/v1/admin/subjects/$SUBJECT_ID" "{\"code\":\"$SUBJECT_CODE\",\"name\":\"DEVELOPMENT DATA Subject Updated $STAMP\",\"category\":\"RELIGIOUS\",\"active\":true}")" 200
curl -fsS "$BASE/api/v1/admin/subjects" -H "Authorization: Bearer $SUPER" | python3 -c 'import json,sys; sid=sys.argv[1]; rows=json.load(sys.stdin)["data"]; r=next((x for x in rows if x["id"]==sid),None); assert r and r["active"] is True and r["category"]=="RELIGIOUS"; print("PASS subject create/update")' "$SUBJECT_ID"

# Kajian operational publish/unpublish remains a real public vertical slice.
KAJIAN_SLUG="phase35-kajian-$STAMP"
KAJIAN_START=$(date -u -d '+7 days' +%Y-%m-%dT%H:%M:%SZ)
KAJIAN=$(curl -fsS -X POST "$BASE/api/v1/admin/kajian" -H "Authorization: Bearer $SUPER" -H 'Content-Type: application/json' -d "{\"title\":\"DEVELOPMENT DATA Kajian $STAMP\",\"slug\":\"$KAJIAN_SLUG\",\"description\":\"Development-only Phase35 kajian\",\"speaker\":\"Ustadz Demo\",\"start_at\":\"$KAJIAN_START\",\"end_at\":null,\"location\":\"Masjid Demo\",\"map_url\":\"\",\"live_url\":\"\",\"poster_url\":\"\",\"published\":false}")
KAJIAN_ID=$(printf '%s' "$KAJIAN" | data_id)
expect_code 'kajian publish' "$(status "$SUPER" PATCH "/api/v1/admin/kajian/$KAJIAN_ID" "{\"title\":\"DEVELOPMENT DATA Kajian $STAMP\",\"slug\":\"$KAJIAN_SLUG\",\"description\":\"Development-only Phase35 kajian\",\"speaker\":\"Ustadz Demo\",\"start_at\":\"$KAJIAN_START\",\"end_at\":null,\"location\":\"Masjid Demo\",\"map_url\":\"\",\"live_url\":\"\",\"poster_url\":\"\",\"published\":true}")" 200
curl -fsS "$BASE/api/v1/kajian" | python3 -c 'import json,sys; kid=sys.argv[1]; rows=json.load(sys.stdin)["data"]; assert any(x["id"]==kid for x in rows); print("PASS kajian create/edit/publish -> public API")' "$KAJIAN_ID"
expect_code 'kajian unpublish' "$(status "$SUPER" PATCH "/api/v1/admin/kajian/$KAJIAN_ID" "{\"title\":\"DEVELOPMENT DATA Kajian $STAMP\",\"slug\":\"$KAJIAN_SLUG\",\"description\":\"Development-only Phase35 kajian\",\"speaker\":\"Ustadz Demo\",\"start_at\":\"$KAJIAN_START\",\"end_at\":null,\"location\":\"Masjid Demo\",\"map_url\":\"\",\"live_url\":\"\",\"poster_url\":\"\",\"published\":false}")" 200

# Grade draft -> edit -> publish -> guardian read -> immutable after publish.
NOTIF_BEFORE=$(curl -fsS "$BASE/api/v1/notifications" -H "Authorization: Bearer $GUARDIAN" | json_count)
GRADE=$(curl -fsS -X POST "$BASE/api/v1/grades" -H "Authorization: Bearer $SUPER" -H 'Content-Type: application/json' -d "{\"student_id\":\"$DEMO_STUDENT\",\"subject_id\":\"$SUBJECT_ID\",\"academic_year\":\"2026/2027\",\"semester\":\"1\",\"assessment_type\":\"PHASE35_$STAMP\",\"score\":80,\"grade\":\"B\",\"teacher_note\":\"DEVELOPMENT DATA draft\",\"published\":false}")
GRADE_ID=$(printf '%s' "$GRADE" | data_id)
expect_code 'grade draft update' "$(status "$SUPER" PATCH "/api/v1/admin/grades/$GRADE_ID" "{\"student_id\":\"$DEMO_STUDENT\",\"subject_id\":\"$SUBJECT_ID\",\"academic_year\":\"2026/2027\",\"semester\":\"1\",\"assessment_type\":\"PHASE35_$STAMP\",\"score\":91,\"grade\":\"A\",\"teacher_note\":\"DEVELOPMENT DATA updated draft\",\"published\":false}")" 200
expect_code 'grade publish' "$(status "$SUPER" PATCH "/api/v1/admin/grades/$GRADE_ID/publish")" 200
for _ in $(seq 1 15); do
  if curl -fsS "$BASE/api/v1/students/$DEMO_STUDENT/grades" -H "Authorization: Bearer $GUARDIAN" | contains_id "$GRADE_ID"; then FOUND_GRADE=1; break; fi
  sleep 1
 done
[[ ${FOUND_GRADE:-0} == 1 ]] || { echo 'FAIL published grade not visible to guardian'; exit 1; }
echo 'PASS grade publish -> guardian read'
expect_code 'published grade immutable' "$(status "$SUPER" PATCH "/api/v1/admin/grades/$GRADE_ID" "{\"student_id\":\"$DEMO_STUDENT\",\"subject_id\":\"$SUBJECT_ID\",\"academic_year\":\"2026/2027\",\"semester\":\"1\",\"assessment_type\":\"PHASE35_$STAMP\",\"score\":92,\"grade\":\"A\",\"teacher_note\":\"must fail\",\"published\":false}")" 409

# Report draft -> publish -> guardian read and event notification.
REPORT=$(curl -fsS -X POST "$BASE/api/v1/admin/reports" -H "Authorization: Bearer $SUPER" -H 'Content-Type: application/json' -d "{\"student_id\":\"$DEMO_STUDENT\",\"academic_year\":\"2026/2027\",\"semester\":\"1\",\"report_type\":\"PHASE35_$STAMP\"}")
REPORT_ID=$(printf '%s' "$REPORT" | data_id)
expect_code 'report publish' "$(status "$SUPER" PATCH "/api/v1/admin/reports/$REPORT_ID/publish")" 200
for _ in $(seq 1 15); do
  if curl -fsS "$BASE/api/v1/students/$DEMO_STUDENT/reports" -H "Authorization: Bearer $GUARDIAN" | contains_id "$REPORT_ID"; then FOUND_REPORT=1; break; fi
  sleep 1
 done
[[ ${FOUND_REPORT:-0} == 1 ]] || { echo 'FAIL published report not visible to guardian'; exit 1; }
echo 'PASS report publish -> guardian read'
for _ in $(seq 1 15); do
  NOTIF_AFTER=$(curl -fsS "$BASE/api/v1/notifications" -H "Authorization: Bearer $GUARDIAN" | json_count)
  if (( NOTIF_AFTER >= NOTIF_BEFORE + 2 )); then FOUND_NOTIF=1; break; fi
  sleep 1
 done
[[ ${FOUND_NOTIF:-0} == 1 ]] || { echo "FAIL expected grade+report guardian notifications; before=$NOTIF_BEFORE after=${NOTIF_AFTER:-?}"; exit 1; }
echo 'PASS grade/report events -> guardian notifications'

# Donation campaign and payment method lifecycle. No hard delete.
METHOD_CODE="P35BANK$STAMP"
METHOD=$(curl -fsS -X POST "$BASE/api/v1/admin/donation/payment-methods" -H "Authorization: Bearer $SUPER" -H 'Content-Type: application/json' -d "{\"method_code\":\"$METHOD_CODE\",\"display_name\":\"DEVELOPMENT DATA Bank $STAMP\",\"bank_name\":\"Demo Bank\",\"account_number\":\"000$STAMP\",\"account_holder\":\"Zabisa Development\",\"instructions\":\"DEVELOPMENT DATA only\"}")
METHOD_ID=$(printf '%s' "$METHOD" | data_id)
expect_code 'payment method deactivate' "$(status "$SUPER" PATCH "/api/v1/admin/donation/payment-methods/$METHOD_ID" "{\"method_code\":\"$METHOD_CODE\",\"display_name\":\"DEVELOPMENT DATA Bank Updated $STAMP\",\"bank_name\":\"Demo Bank\",\"account_number\":\"000$STAMP\",\"account_holder\":\"Zabisa Development\",\"instructions\":\"DEVELOPMENT DATA inactive\",\"active\":false}")" 200
curl -fsS "$BASE/api/v1/admin/donation/payment-methods" -H "Authorization: Bearer $SUPER" | python3 -c 'import json,sys; mid=sys.argv[1]; rows=json.load(sys.stdin)["data"]; r=next((x for x in rows if x["id"]==mid),None); assert r and r["active"] is False; print("PASS admin payment method lifecycle")' "$METHOD_ID"
if curl -fsS "$BASE/api/v1/donation/payment-methods" | python3 -c 'import json,sys; code=sys.argv[1]; rows=json.load(sys.stdin).get("data",[]); raise SystemExit(0 if any(x.get("method_code")==code for x in rows) else 1)' "$METHOD_CODE"; then echo 'FAIL inactive payment method exposed publicly'; exit 1; fi
echo 'PASS inactive payment method hidden from public API'

SLUG="phase35-$STAMP"
CAMPAIGN=$(curl -fsS -X POST "$BASE/api/v1/admin/donation/campaigns" -H "Authorization: Bearer $SUPER" -H 'Content-Type: application/json' -d "{\"name\":\"DEVELOPMENT DATA Campaign $STAMP\",\"slug\":\"$SLUG\",\"description\":\"Development-only operational verification\",\"category\":\"Pendidikan Santri\",\"target_amount\":1000000,\"cover_url\":\"\",\"deadline\":null}")
CAMPAIGN_ID=$(printf '%s' "$CAMPAIGN" | data_id)
CAMPAIGN_UPDATE=$(curl -fsS -X POST "$BASE/api/v1/admin/donation/campaigns/$CAMPAIGN_ID/updates" -H "Authorization: Bearer $SUPER" -H 'Content-Type: application/json' -d "{\"title\":\"DEVELOPMENT DATA Phase35 Update $STAMP\",\"body\":\"Development-only campaign update verification\"}")
CAMPAIGN_UPDATE_ID=$(printf '%s' "$CAMPAIGN_UPDATE" | data_id)
curl -fsS "$BASE/api/v1/donation/campaigns/$CAMPAIGN_ID/updates" | python3 -c 'import json,sys; uid=sys.argv[1]; rows=json.load(sys.stdin).get("data",[]); assert any(str(x.get("id"))==uid for x in rows); print("PASS campaign update create -> public read")' "$CAMPAIGN_UPDATE_ID"
expect_code 'campaign pause' "$(status "$SUPER" PATCH "/api/v1/admin/donation/campaigns/$CAMPAIGN_ID" "{\"name\":\"DEVELOPMENT DATA Campaign Updated $STAMP\",\"slug\":\"$SLUG\",\"description\":\"Development-only operational verification updated\",\"category\":\"Pendidikan Santri\",\"target_amount\":1250000,\"cover_url\":\"\",\"deadline\":\"\",\"status\":\"PAUSED\"}")" 200
curl -fsS "$BASE/api/v1/admin/donation/campaigns" -H "Authorization: Bearer $SUPER" | python3 -c 'import json,sys; cid=sys.argv[1]; rows=json.load(sys.stdin)["data"]; r=next((x for x in rows if x["id"]==cid),None); assert r and r["status"]=="PAUSED" and float(r["target_amount"])==1250000; print("PASS campaign create/update/lifecycle")' "$CAMPAIGN_ID"
if curl -fsS "$BASE/api/v1/donation/campaigns" | contains_id "$CAMPAIGN_ID"; then echo 'FAIL paused campaign exposed as active public campaign'; exit 1; fi
echo 'PASS paused campaign hidden from public active list'
expect_code 'campaign archive' "$(status "$SUPER" PATCH "/api/v1/admin/donation/campaigns/$CAMPAIGN_ID" "{\"name\":\"DEVELOPMENT DATA Campaign Updated $STAMP\",\"slug\":\"$SLUG\",\"description\":\"Development-only operational verification updated\",\"category\":\"Pendidikan Santri\",\"target_amount\":1250000,\"cover_url\":\"\",\"deadline\":\"\",\"status\":\"ARCHIVED\"}")" 200

# Manual donation operational path: real transaction state is verified by backend/admin.
ACTIVE_CAMPAIGNS=$(curl -fsS "$BASE/api/v1/donation/campaigns")
ACTIVE_CAMPAIGN_ID=$(printf '%s' "$ACTIVE_CAMPAIGNS" | python3 -c 'import json,sys; rows=json.load(sys.stdin).get("data",[]); assert rows, "no active campaign available"; print(rows[0]["id"])')
ACTIVE_METHOD=$(curl -fsS "$BASE/api/v1/donation/payment-methods" | python3 -c 'import json,sys; rows=json.load(sys.stdin).get("data",[]); assert rows, "no active payment method available"; print(rows[0]["method_code"])')
DONATION=$(curl -fsS -X POST "$BASE/api/v1/donations" -H 'Content-Type: application/json' -H "Idempotency-Key: phase35-$STAMP" -d "{\"campaign_id\":\"$ACTIVE_CAMPAIGN_ID\",\"donor_name\":\"DEVELOPMENT DATA Phase35\",\"donor_email\":\"phase35-$STAMP@example.invalid\",\"anonymous\":true,\"message\":\"Development verification\",\"amount\":12345,\"payment_method\":\"$ACTIVE_METHOD\"}")
DONATION_ID=$(printf '%s' "$DONATION" | data_id)
expect_code 'manual donation verification' "$(status "$SUPER" PATCH "/api/v1/admin/donations/$DONATION_ID/verify")" 200
curl -fsS "$BASE/api/v1/donations/$DONATION_ID" | python3 -c 'import json,sys; d=json.load(sys.stdin)["data"]; assert d["status"]=="PAID"; print("PASS donation create -> admin verify -> PAID")'

# Notification compose through real service and guardian inbox persistence.
TITLE="Phase35 operational $STAMP"
NOTIFY=$(curl -fsS -X POST "$BASE/api/v1/admin/notifications" -H "Authorization: Bearer $SUPER" -H 'Content-Type: application/json' -d "{\"user_id\":\"$GUARDIAN_ID\",\"type\":\"ANNOUNCEMENT\",\"title\":\"$TITLE\",\"message\":\"DEVELOPMENT DATA operational notification\",\"deep_link\":\"zabisa://notifications\",\"scheduled_at\":\"\"}")
NOTIFY_ID=$(printf '%s' "$NOTIFY" | data_id)
curl -fsS "$BASE/api/v1/notifications" -H "Authorization: Bearer $GUARDIAN" | python3 -c 'import json,sys; nid=sys.argv[1]; rows=json.load(sys.stdin)["data"]; assert any(x["id"]==nid for x in rows); print("PASS notification compose -> guardian inbox")' "$NOTIFY_ID"

# Finalize development fixture instead of destructive delete.
expect_code 'development student deactivate' "$(status "$SUPER" PATCH "/api/v1/admin/students/$STUDENT_ID" "{\"student_no\":\"$STUDENT_NO\",\"full_name\":\"DEVELOPMENT DATA Phase35 Student Updated $STAMP\",\"photo_url\":\"\",\"class_name\":\"Demo B\",\"program_name\":\"Tahfidz Intensif\",\"academic_year\":\"2026/2027\",\"status\":\"INACTIVE\"}")" 200
expect_code 'development subject deactivate' "$(status "$SUPER" PATCH "/api/v1/admin/subjects/$SUBJECT_ID" "{\"code\":\"$SUBJECT_CODE\",\"name\":\"DEVELOPMENT DATA Subject Updated $STAMP\",\"category\":\"RELIGIOUS\",\"active\":false}")" 200

echo '=== PHASE 3.5 OPERATIONAL BACKOFFICE: PASS ==='
