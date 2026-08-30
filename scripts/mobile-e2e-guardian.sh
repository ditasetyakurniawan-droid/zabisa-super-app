#!/usr/bin/env bash
set -euo pipefail
BASE=${ZABISA_API_URL:-http://127.0.0.1:8088}
GUARDIAN_EMAIL=${ZABISA_GUARDIAN_EMAIL:-guardian@zabisa.local}
GUARDIAN_PASSWORD=${ZABISA_GUARDIAN_PASSWORD:-ChangeMe123!}
ADMIN_EMAIL=${ZABISA_ADMIN_EMAIL:-admin@zabisa.local}
ADMIN_PASSWORD=${ZABISA_ADMIN_PASSWORD:-ChangeMe123!}
MUTATE=${ZABISA_E2E_MUTATE:-0}
REQUIRE_POPULATED=${ZABISA_REQUIRE_POPULATED:-0}
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT

count_data(){ python3 -c 'import json,sys; x=json.load(sys.stdin).get("data") or []; print(len(x))'; }
fetch(){ local url=$1 token=$2 out=$3; curl -sS -o "$out" -w '%{http_code}' "$url" -H "Authorization: Bearer $token"; }

echo '=== Guardian E2E ==='
curl -fsS "$BASE/health/live" >/dev/null || { echo "FAIL API gateway unavailable: $BASE"; exit 1; }
LOGIN=$(curl -fsS -X POST "$BASE/api/v1/auth/login" -H 'Content-Type: application/json' -d "{\"email\":\"$GUARDIAN_EMAIL\",\"password\":\"$GUARDIAN_PASSWORD\",\"device_id\":\"mobile-e2e-guardian\"}")
TOKEN=$(printf '%s' "$LOGIN" | python3 -c 'import json,sys; print(json.load(sys.stdin)["data"]["access_token"])')
echo 'PASS guardian login'

STUDENTS=$(curl -fsS "$BASE/api/v1/guardian/students" -H "Authorization: Bearer $TOKEN")
STUDENT_ID=$(printf '%s' "$STUDENTS" | python3 -c 'import json,sys; x=json.load(sys.stdin)["data"]; assert x,"no linked student"; print(x[0]["id"])')
STUDENT_NAME=$(printf '%s' "$STUDENTS" | python3 -c 'import json,sys; x=json.load(sys.stdin)["data"]; print(x[0].get("full_name") or x[0]["id"])')
echo "PASS linked student: $STUDENT_NAME ($STUDENT_ID)"

fail=0
check_endpoint(){
  local label=$1 path=$2 file=$3 require=${4:-0}
  local code n
  code=$(fetch "$BASE$path" "$TOKEN" "$file")
  if [[ "$code" == 200 ]]; then
    n=$(cat "$file" | count_data)
    echo "PASS $label: $n item(s)"
    if [[ "$REQUIRE_POPULATED" == 1 && "$require" == 1 && "$n" -lt 1 ]]; then
      echo "FAIL $label must contain development data for populated UI validation"
      fail=1
    fi
  else
    echo "FAIL $label: HTTP $code -> $path"
    cat "$file"; echo
    fail=1
  fi
}
check_endpoint 'tahfidz' "/api/v1/tahfidz/students/$STUDENT_ID/entries" "$TMP/tahfidz.json" 1
check_endpoint 'grades' "/api/v1/students/$STUDENT_ID/grades" "$TMP/grades.json" 1
check_endpoint 'attendance' "/api/v1/guardian/students/$STUDENT_ID/attendance" "$TMP/attendance.json" 1
check_endpoint 'reports' "/api/v1/students/$STUDENT_ID/reports" "$TMP/reports.json" 1
check_endpoint 'notifications' '/api/v1/notifications' "$TMP/notifications.json" 1

if [[ "$MUTATE" == 1 ]]; then
  echo '=== Mutating vertical-slice check: Tahfidz -> outbox -> notification ==='
  ADMIN_LOGIN=$(curl -fsS -X POST "$BASE/api/v1/auth/login" -H 'Content-Type: application/json' -d "{\"email\":\"$ADMIN_EMAIL\",\"password\":\"$ADMIN_PASSWORD\",\"device_id\":\"mobile-e2e-admin\"}")
  ADMIN_TOKEN=$(printf '%s' "$ADMIN_LOGIN" | python3 -c 'import json,sys; print(json.load(sys.stdin)["data"]["access_token"])')
  STAMP=$(date +%s); TODAY=$(date +%F)
  curl -fsS -X POST "$BASE/api/v1/tahfidz/entries" -H "Authorization: Bearer $ADMIN_TOKEN" -H 'Content-Type: application/json' -d "{\"student_id\":\"$STUDENT_ID\",\"activity_date\":\"$TODAY\",\"surah\":\"Al-Fatihah\",\"ayah_start\":1,\"ayah_end\":7,\"activity_type\":\"MURAJAAH\",\"teacher_note\":\"Mobile E2E $STAMP\"}" >/dev/null
  found=0
  for _ in $(seq 1 15); do
    sleep 2
    curl -fsS "$BASE/api/v1/notifications" -H "Authorization: Bearer $TOKEN" >"$TMP/notifications-after.json"
    if python3 - "$TMP/notifications-after.json" <<'PY'
import json,sys
items=json.load(open(sys.argv[1])).get('data') or []
raise SystemExit(0 if any(x.get('type')=='TAHFIDZ' for x in items) else 1)
PY
    then found=1; break; fi
  done
  if [[ "$found" == 1 ]]; then echo 'PASS Tahfidz event reached guardian notification inbox'; else echo 'FAIL Tahfidz notification not observed'; fail=1; fi
fi

if [[ "$fail" != 0 ]]; then
  echo '=== RESULT: FAILED ==='
  echo 'A required Guardian mobile dependency is missing, empty when populated validation is required, or unhealthy.'
  exit 1
fi
echo '=== RESULT: PASS ==='
echo 'Guardian API flow is healthy. Final UI validation must still be performed on the physical device.'
