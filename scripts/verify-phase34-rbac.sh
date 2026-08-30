#!/usr/bin/env bash
set -euo pipefail
BASE=${ZABISA_API_URL:-http://127.0.0.1:8088}
ADMIN_WEB=${ZABISA_ADMIN_WEB_URL:-http://127.0.0.1:3001}
PASS=${ZABISA_DEV_PASSWORD:-ChangeMe123!}

login(){ local email=$1; curl -fsS "$BASE/api/v1/auth/login" -H 'Content-Type: application/json' -d "{\"email\":\"$email\",\"password\":\"$PASS\",\"device_id\":\"phase34-rbac\"}" | python3 -c 'import json,sys; print(json.load(sys.stdin)["data"]["access_token"])'; }
status(){ local token=$1 path=$2; curl -sS -o /tmp/zabisa-rbac-body.json -w '%{http_code}' "$BASE$path" -H "Authorization: Bearer $token"; }
expect(){ local label=$1 got=$2 want=$3; if [[ "$got" != "$want" ]]; then echo "FAIL $label: HTTP $got expected $want"; cat /tmp/zabisa-rbac-body.json 2>/dev/null || true; exit 1; fi; echo "PASS $label: HTTP $got"; }

echo '=== Phase 3.4 RBAC integration ==='
SUPER=$(login admin@zabisa.local)
CONTENT=$(login content@zabisa.local)
FINANCE=$(login finance@zabisa.local)
OPERATOR=$(login operator@zabisa.local)
USTADZ=$(login ustadz@zabisa.local)
TEACHER=$(login teacher@zabisa.local)
GUARDIAN=$(login guardian@zabisa.local)

expect 'SUPER_ADMIN users' "$(status "$SUPER" /api/v1/admin/users)" 200
expect 'SUPER_ADMIN audit' "$(status "$SUPER" /api/v1/admin/audit-logs)" 200
expect 'CONTENT_EDITOR content' "$(status "$CONTENT" /api/v1/admin/content)" 200
expect 'CONTENT_EDITOR donation denied' "$(status "$CONTENT" /api/v1/admin/donations)" 403
expect 'CONTENT_EDITOR students denied' "$(status "$CONTENT" /api/v1/admin/students)" 403
expect 'FINANCE donations' "$(status "$FINANCE" /api/v1/admin/donations)" 200
expect 'FINANCE content denied' "$(status "$FINANCE" /api/v1/admin/content)" 403
expect 'OPERATOR students' "$(status "$OPERATOR" /api/v1/admin/students)" 200
expect 'OPERATOR attendance' "$(status "$OPERATOR" /api/v1/admin/attendance)" 200
expect 'OPERATOR donation denied' "$(status "$OPERATOR" /api/v1/admin/donations)" 403
expect 'USTADZ tahfidz' "$(status "$USTADZ" /api/v1/tahfidz/entries)" 200
expect 'USTADZ academic denied' "$(status "$USTADZ" /api/v1/admin/grades)" 403
expect 'GURU_AKADEMIK academic' "$(status "$TEACHER" /api/v1/admin/grades)" 200
expect 'GURU_AKADEMIK tahfidz denied' "$(status "$TEACHER" /api/v1/tahfidz/entries)" 403
expect 'GUARDIAN admin denied' "$(status "$GUARDIAN" /api/v1/admin/content)" 403

# Security invariant: role change must invalidate the old access token immediately at API Gateway.
TMP_STAMP=$(date +%s)
TMP_EMAIL="rbac-e2e-$TMP_STAMP@zabisa.local"
TMP_CREATE=$(curl -fsS -X POST "$BASE/api/v1/admin/users" -H "Authorization: Bearer $SUPER" -H 'Content-Type: application/json' -d "{\"email\":\"$TMP_EMAIL\",\"phone\":\"\",\"password\":\"$PASS\",\"display_name\":\"RBAC E2E $TMP_STAMP\",\"role\":\"CONTENT_EDITOR\"}")
TMP_ID=$(printf '%s' "$TMP_CREATE" | python3 -c 'import json,sys; print(json.load(sys.stdin)["data"]["id"])')
TMP_TOKEN=$(login "$TMP_EMAIL")
expect 'temporary CONTENT_EDITOR before role change' "$(status "$TMP_TOKEN" /api/v1/admin/content)" 200
curl -fsS -X PATCH "$BASE/api/v1/admin/users/$TMP_ID" -H "Authorization: Bearer $SUPER" -H 'Content-Type: application/json' -d '{"role":"OPERATOR","status":"ACTIVE"}' >/dev/null
expect 'stale token rejected after role change' "$(status "$TMP_TOKEN" /api/v1/admin/content)" 401
TMP_TOKEN_NEW=$(login "$TMP_EMAIL")
expect 'new OPERATOR token students allowed' "$(status "$TMP_TOKEN_NEW" /api/v1/admin/students)" 200
expect 'new OPERATOR token content denied' "$(status "$TMP_TOKEN_NEW" /api/v1/admin/content)" 403
curl -fsS -X PATCH "$BASE/api/v1/admin/users/$TMP_ID" -H "Authorization: Bearer $SUPER" -H 'Content-Type: application/json' -d '{"role":"OPERATOR","status":"INACTIVE"}' >/dev/null
echo 'PASS role change session revocation + stale JWT rejection'

# Security invariant: current SUPER_ADMIN cannot demote/deactivate itself through the API.
ME=$(curl -fsS "$BASE/api/v1/auth/me" -H "Authorization: Bearer $SUPER")
SUPER_ID=$(printf '%s' "$ME" | python3 -c 'import json,sys; print(json.load(sys.stdin)["data"]["id"])')
LOCKOUT_CODE=$(curl -sS -o /tmp/zabisa-rbac-lockout.json -w '%{http_code}' -X PATCH "$BASE/api/v1/admin/users/$SUPER_ID" -H "Authorization: Bearer $SUPER" -H 'Content-Type: application/json' -d '{"role":"ADMIN","status":"ACTIVE"}')
if [[ "$LOCKOUT_CODE" != 409 ]]; then echo "FAIL self-demotion protection: HTTP $LOCKOUT_CODE expected 409"; cat /tmp/zabisa-rbac-lockout.json; exit 1; fi
echo 'PASS self-demotion blocked: HTTP 409'

# Audit entry for the role update must carry before/after and trace/request correlation.
AUDIT=$(curl -fsS "$BASE/api/v1/admin/audit-logs" -H "Authorization: Bearer $SUPER")
printf '%s' "$AUDIT" | python3 -c 'import json,sys; uid=sys.argv[1]; rows=json.load(sys.stdin).get("data",[]); matches=[r for r in rows if str(r.get("resource_id"))==uid and r.get("action")=="USER_ACCESS_CHANGED"]; assert matches, "FAIL role-change audit record missing"; r=matches[0]; assert r.get("before") and r.get("after"), "FAIL audit before/after missing"; assert r.get("trace_id") or r.get("request_id"), "FAIL audit correlation id missing"; print("PASS role-change audit before/after + correlation")' "$TMP_ID"

# CMS vertical slice: create draft -> publish -> public read -> unpublish.
STAMP=$(date +%s)
SLUG="phase34-rbac-$STAMP"
CREATE=$(curl -fsS -X POST "$BASE/api/v1/admin/content" -H "Authorization: Bearer $CONTENT" -H 'Content-Type: application/json' -d "{\"type\":\"NEWS\",\"title\":\"Phase 3.4 RBAC E2E $STAMP\",\"slug\":\"$SLUG\",\"summary\":\"DEVELOPMENT DATA - RBAC E2E\",\"body\":\"Development-only CMS vertical slice verification.\",\"image_url\":\"\",\"published\":false}")
CONTENT_ID=$(printf '%s' "$CREATE" | python3 -c 'import json,sys; print(json.load(sys.stdin)["data"]["id"])')
curl -fsS -X PATCH "$BASE/api/v1/admin/content/$CONTENT_ID" -H "Authorization: Bearer $CONTENT" -H 'Content-Type: application/json' -d "{\"type\":\"NEWS\",\"title\":\"Phase 3.4 RBAC E2E $STAMP\",\"slug\":\"$SLUG\",\"summary\":\"DEVELOPMENT DATA - published through backoffice API\",\"body\":\"Development-only CMS vertical slice verification.\",\"image_url\":\"\",\"published\":true}" >/dev/null
PUBLIC=$(curl -fsS "$BASE/api/v1/content?type=NEWS")
printf '%s' "$PUBLIC" | python3 -c 'import json,sys; content_id=sys.argv[1]; body=json.load(sys.stdin); ok=any(str(x.get("id"))==content_id for x in body.get("data",[])); print("PASS CMS create -> publish -> public API") if ok else (_ for _ in ()).throw(SystemExit("FAIL published CMS content not visible in public API"))' "$CONTENT_ID"
curl -fsS -X PATCH "$BASE/api/v1/admin/content/$CONTENT_ID" -H "Authorization: Bearer $CONTENT" -H 'Content-Type: application/json' -d "{\"type\":\"NEWS\",\"title\":\"Phase 3.4 RBAC E2E $STAMP\",\"slug\":\"$SLUG\",\"summary\":\"DEVELOPMENT DATA - archived after verification\",\"body\":\"Development-only CMS vertical slice verification.\",\"image_url\":\"\",\"published\":false}" >/dev/null

# Backoffice must reject a guardian even though guardian credentials are valid for mobile.
if curl -fsS --max-time 3 "$ADMIN_WEB/login" >/dev/null 2>&1; then
  CODE=$(curl -sS -o /tmp/zabisa-backoffice-guardian.json -w '%{http_code}' -X POST "$ADMIN_WEB/api/auth/login" -H 'Content-Type: application/json' -d "{\"email\":\"guardian@zabisa.local\",\"password\":\"$PASS\",\"device_id\":\"phase34-backoffice\"}")
  if [[ "$CODE" != 403 ]]; then echo "FAIL guardian backoffice login: HTTP $CODE expected 403"; cat /tmp/zabisa-backoffice-guardian.json; exit 1; fi
  echo 'PASS guardian backoffice login denied: HTTP 403'
else
  echo 'WARN admin-web not reachable; guardian web-login assertion skipped'
fi

echo '=== PHASE 3.4 RBAC: PASS ==='
