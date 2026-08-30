#!/usr/bin/env bash
set -euo pipefail
BASE="${ZABISA_API_URL:-http://127.0.0.1:8088}"
PASSWORD="${ZABISA_DEV_PASSWORD:-ChangeMe123!}"
RUN="$(date +%s)"
EMAIL="phase354.guardian.$RUN@example.invalid"
STUDENT_NO="ZB-GUARD-$RUN"
STUDENT_NAME="DEVELOPMENT DATA Guardian Link Student $RUN"
login(){ curl -fsS "$BASE/api/v1/auth/login" -H 'Content-Type: application/json' -d "{\"email\":\"$1\",\"password\":\"$2\",\"device_id\":\"$3\"}" | python3 -c 'import json,sys; print(json.load(sys.stdin)["data"]["access_token"])'; }
id(){ python3 -c 'import json,sys; print(json.load(sys.stdin)["data"]["id"])'; }
expect(){ local label="$1" expected="$2"; shift 2; local code; code="$(curl -sS -o /tmp/zabisa-phase354.json -w '%{http_code}' "$@")"; [ "$code" = "$expected" ] || { echo "FAIL $label HTTP $code expected $expected"; cat /tmp/zabisa-phase354.json; return 1; }; echo "PASS $label: HTTP $code"; }
SUPER="$(login admin@zabisa.local "$PASSWORD" phase354-super)"
GJSON="$(curl -fsS -X POST "$BASE/api/v1/admin/users" -H "Authorization: Bearer $SUPER" -H 'Content-Type: application/json' -d "{\"display_name\":\"DEVELOPMENT DATA Guardian $RUN\",\"email\":\"$EMAIL\",\"phone\":\"080000$RUN\",\"password\":\"GuardianDemo123!\",\"role\":\"GUARDIAN\"}")"
GUARDIAN_ID="$(printf '%s' "$GJSON" | id)"; echo "PASS guardian account create: $GUARDIAN_ID"
DUP="$(curl -sS -o /tmp/zabisa-phase354-dup.json -w '%{http_code}' -X POST "$BASE/api/v1/admin/users" -H "Authorization: Bearer $SUPER" -H 'Content-Type: application/json' -d "{\"display_name\":\"Duplicate\",\"email\":\"$EMAIL\",\"password\":\"GuardianDemo123!\",\"role\":\"GUARDIAN\"}")"
[ "$DUP" = 409 ] || { echo "FAIL duplicate email HTTP $DUP"; cat /tmp/zabisa-phase354-dup.json; exit 1; }
python3 -c 'import json; b=json.load(open("/tmp/zabisa-phase354-dup.json")); assert b["error"]["code"]=="EMAIL_EXISTS"; print("PASS duplicate email returns EMAIL_EXISTS")'
SJSON="$(curl -fsS -X POST "$BASE/api/v1/admin/students" -H "Authorization: Bearer $SUPER" -H 'Content-Type: application/json' -d "{\"student_no\":\"$STUDENT_NO\",\"full_name\":\"$STUDENT_NAME\",\"class_name\":\"Kelas Demo\",\"program_name\":\"Tahfidz\",\"academic_year\":\"2026/2027\"}")"
STUDENT_ID="$(printf '%s' "$SJSON" | id)"; echo "PASS student create: $STUDENT_ID"
LJSON="$(curl -fsS -X POST "$BASE/api/v1/admin/guardian-links" -H "Authorization: Bearer $SUPER" -H 'Content-Type: application/json' -d "{\"guardian_user_id\":\"$GUARDIAN_ID\",\"student_id\":\"$STUDENT_ID\",\"relationship\":\"FATHER\"}")"
LINK_ID="$(printf '%s' "$LJSON" | id)"; printf '%s' "$LJSON" | python3 -c 'import json,sys; assert json.load(sys.stdin)["data"]["status"]=="PENDING"; print("PASS relationship starts PENDING")'
expect "guardian approve" 200 -X PATCH "$BASE/api/v1/admin/guardian-links/$LINK_ID/approve" -H "Authorization: Bearer $SUPER"
GTOKEN="$(login "$EMAIL" 'GuardianDemo123!' phase354-guardian)"
curl -fsS "$BASE/api/v1/guardian/students" -H "Authorization: Bearer $GTOKEN" | python3 -c 'import json,sys; sid=sys.argv[1]; assert any(x.get("id")==sid for x in json.load(sys.stdin)["data"]); print("PASS approved child appears in guardian read model")' "$STUDENT_ID"
expect "guardian revoke" 200 -X PATCH "$BASE/api/v1/admin/guardian-links/$LINK_ID/revoke" -H "Authorization: Bearer $SUPER"
expect "revoked guardian private grade denied" 403 "$BASE/api/v1/students/$STUDENT_ID/grades" -H "Authorization: Bearer $GTOKEN"
RJSON="$(curl -fsS -X POST "$BASE/api/v1/admin/guardian-links" -H "Authorization: Bearer $SUPER" -H 'Content-Type: application/json' -d "{\"guardian_user_id\":\"$GUARDIAN_ID\",\"student_id\":\"$STUDENT_ID\",\"relationship\":\"FATHER\"}")"
RELINK_ID="$(printf '%s' "$RJSON" | id)"; [ "$RELINK_ID" = "$LINK_ID" ] || { echo 'FAIL re-request relationship identity'; exit 1; }
printf '%s' "$RJSON" | python3 -c 'import json,sys; d=json.load(sys.stdin)["data"]; assert d["status"]=="PENDING" and d["re_requested"] is True; print("PASS revoked relationship re-requested as PENDING")'
expect "guardian re-approve" 200 -X PATCH "$BASE/api/v1/admin/guardian-links/$LINK_ID/approve" -H "Authorization: Bearer $SUPER"
GTOKEN2="$(login "$EMAIL" 'GuardianDemo123!' phase354-guardian2)"
curl -fsS "$BASE/api/v1/guardian/students" -H "Authorization: Bearer $GTOKEN2" | python3 -c 'import json,sys; sid=sys.argv[1]; assert any(x.get("id")==sid for x in json.load(sys.stdin)["data"]); print("PASS re-approved relationship restores access")' "$STUDENT_ID"
expect "cleanup relationship revoke" 200 -X PATCH "$BASE/api/v1/admin/guardian-links/$LINK_ID/revoke" -H "Authorization: Bearer $SUPER"
expect "cleanup student deactivate" 200 -X PATCH "$BASE/api/v1/admin/students/$STUDENT_ID" -H "Authorization: Bearer $SUPER" -H 'Content-Type: application/json' -d "{\"student_no\":\"$STUDENT_NO\",\"full_name\":\"$STUDENT_NAME\",\"photo_url\":\"\",\"class_name\":\"Kelas Demo\",\"program_name\":\"Tahfidz\",\"academic_year\":\"2026/2027\",\"status\":\"INACTIVE\"}"
expect "cleanup guardian deactivate" 200 -X PATCH "$BASE/api/v1/admin/users/$GUARDIAN_ID" -H "Authorization: Bearer $SUPER" -H 'Content-Type: application/json' -d '{"role":"GUARDIAN","status":"INACTIVE"}'
echo "=== GUARDIAN ONBOARDING: PASS ==="
