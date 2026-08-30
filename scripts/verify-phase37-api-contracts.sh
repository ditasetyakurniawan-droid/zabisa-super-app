#!/usr/bin/env bash
set -euo pipefail
BASE="${ZABISA_API_URL:-http://127.0.0.1:8088}"
PASS="${ZABISA_DEV_PASSWORD:-ChangeMe123!}"
RUN="$(date +%s)"
TMP="/tmp/zabisa-phase37-contract"
mkdir -p "$TMP"

login(){ local email="$1" device="$2"; curl -fsS "$BASE/api/v1/auth/login" -H 'Content-Type: application/json' -d "{\"email\":\"$email\",\"password\":\"$PASS\",\"device_id\":\"$device\"}" | python3 -c 'import json,sys; print(json.load(sys.stdin)["data"]["access_token"])'; }
data_id(){ python3 -c 'import json,sys; print(json.load(sys.stdin)["data"]["id"])'; }
code(){ local token="$1" method="$2" path="$3" body="${4:-}"; if [ -n "$body" ]; then curl -sS -o "$TMP/body.json" -w '%{http_code}' -X "$method" "$BASE$path" -H "Authorization: Bearer $token" -H 'Content-Type: application/json' -H "X-Request-ID: phase37-$RUN" -d "$body"; else curl -sS -o "$TMP/body.json" -w '%{http_code}' -X "$method" "$BASE$path" -H "Authorization: Bearer $token" -H "X-Request-ID: phase37-$RUN"; fi; }
expect(){ local label="$1" got="$2" want="$3"; if [ "$got" != "$want" ]; then echo "FAIL $label: HTTP $got expected $want"; cat "$TMP/body.json" 2>/dev/null || true; exit 1; fi; echo "PASS $label: HTTP $got"; }

SUPER="$(login admin@zabisa.local phase37-super)"
OPERATOR="$(login operator@zabisa.local phase37-operator)"
CONTENT="$(login content@zabisa.local phase37-content)"

echo '=== Phase 3.7 strict UI/API contract integration ==='

# Least privilege: operational roles get narrow directories, not the whole identity directory.
expect 'operator guardian candidates allowed' "$(code "$OPERATOR" GET /api/v1/admin/guardian-candidates)" 200
expect 'operator broad users denied' "$(code "$OPERATOR" GET /api/v1/admin/users)" 403
expect 'content editor notification candidates allowed' "$(code "$CONTENT" GET /api/v1/admin/notification-candidates)" 200
expect 'content editor broad users denied' "$(code "$CONTENT" GET /api/v1/admin/users)" 403

# Student strict create accepts the real Backoffice payload including photo_url/status.
NO="P37-$RUN"
STUDENT="$(curl -fsS -X POST "$BASE/api/v1/admin/students" -H "Authorization: Bearer $SUPER" -H 'Content-Type: application/json' -H "X-Request-ID: phase37-student-$RUN" -d "{\"student_no\":\"$NO\",\"full_name\":\"DEVELOPMENT DATA Phase37 Student $RUN\",\"photo_url\":\"\",\"class_name\":\"Contract A\",\"program_name\":\"Tahfidz\",\"academic_year\":\"2026/2027\",\"status\":\"ACTIVE\"}")"
STUDENT_ID="$(printf '%s' "$STUDENT" | data_id)"
echo "PASS strict student create: $STUDENT_ID"
expect 'student unknown field rejected' "$(code "$SUPER" POST /api/v1/admin/students "{\"student_no\":\"BAD-$RUN\",\"full_name\":\"Bad DTO\",\"unknown_field\":true}")" 400

# Tahfidz target POST owns student_id; PATCH must reject immutable ownership fields.
TARGET="$(curl -fsS -X POST "$BASE/api/v1/tahfidz/targets" -H "Authorization: Bearer $SUPER" -H 'Content-Type: application/json' -H "X-Request-ID: phase37-target-create-$RUN" -d "{\"student_id\":\"$STUDENT_ID\",\"target_juz\":1.5,\"target_date\":\"2026-12-31\"}")"
TARGET_ID="$(printf '%s' "$TARGET" | data_id)"
expect 'Tahfidz PATCH rejects student_id' "$(code "$SUPER" PATCH "/api/v1/tahfidz/targets/$TARGET_ID" "{\"student_id\":\"$STUDENT_ID\",\"target_juz\":2,\"target_date\":\"2027-01-31\"}")" 400
expect 'Tahfidz PATCH strict update DTO succeeds' "$(code "$SUPER" PATCH "/api/v1/tahfidz/targets/$TARGET_ID" '{"target_juz":2,"target_date":"2027-01-31"}')" 200

# Payment-method create does not accept lifecycle active; PATCH owns lifecycle state.
METHOD="P37BANK$RUN"
PAYMENT="$(curl -fsS -X POST "$BASE/api/v1/admin/donation/payment-methods" -H "Authorization: Bearer $SUPER" -H 'Content-Type: application/json' -H "X-Request-ID: phase37-method-create-$RUN" -d "{\"method_code\":\"$METHOD\",\"display_name\":\"DEVELOPMENT DATA Phase37 Bank\",\"bank_name\":\"Demo Bank\",\"account_number\":\"37$RUN\",\"account_holder\":\"Zabisa Development\",\"instructions\":\"Development only\"}")"
METHOD_ID="$(printf '%s' "$PAYMENT" | data_id)"
echo "PASS payment method strict create: $METHOD_ID"
expect 'payment POST rejects active lifecycle field' "$(code "$SUPER" POST /api/v1/admin/donation/payment-methods "{\"method_code\":\"BAD$RUN\",\"display_name\":\"Bad method\",\"active\":false}")" 400
expect 'payment PATCH lifecycle succeeds' "$(code "$SUPER" PATCH "/api/v1/admin/donation/payment-methods/$METHOD_ID" "{\"method_code\":\"$METHOD\",\"display_name\":\"DEVELOPMENT DATA Phase37 Bank\",\"bank_name\":\"Demo Bank\",\"account_number\":\"37$RUN\",\"account_holder\":\"Zabisa Development\",\"instructions\":\"Development only\",\"active\":false}")" 200

# Clean up through lifecycle, never hard delete.
expect 'contract student deactivated' "$(code "$SUPER" PATCH "/api/v1/admin/students/$STUDENT_ID" "{\"student_no\":\"$NO\",\"full_name\":\"DEVELOPMENT DATA Phase37 Student $RUN\",\"photo_url\":\"\",\"class_name\":\"Contract A\",\"program_name\":\"Tahfidz\",\"academic_year\":\"2026/2027\",\"status\":\"INACTIVE\"}")" 200

echo '=== PHASE 3.7 API CONTRACTS: PASS ==='
