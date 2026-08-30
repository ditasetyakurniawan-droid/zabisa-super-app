#!/usr/bin/env bash
set -euo pipefail

BASE="${ZABISA_ADMIN_BASE_URL:-http://127.0.0.1:3001}"
EMAIL="${ZABISA_ADMIN_EMAIL:-admin@zabisa.local}"
PASSWORD="${ZABISA_ADMIN_PASSWORD:-ChangeMe123!}"
ITERATIONS="${ZABISA_ADMIN_RUNTIME_ITERATIONS:-20}"

echo "=== Admin runtime verification ==="

CID="$(docker compose ps -q admin-web)"
if [ -z "$CID" ]; then
  echo "ERROR: admin-web container not found."
  return 1 2>/dev/null || false
fi

STATE="$(docker inspect "$CID" --format='{{.State.Status}}')"
HEALTH="$(docker inspect "$CID" --format='{{if .State.Health}}{{.State.Health.Status}}{{else}}n/a{{end}}')"
RESTARTS="$(docker inspect "$CID" --format='{{.RestartCount}}')"
OOM="$(docker inspect "$CID" --format='{{.State.OOMKilled}}')"

echo "status=$STATE health=$HEALTH restart_count=$RESTARTS oom=$OOM"
[ "$STATE" = "running" ]
[ "$HEALTH" = "healthy" ]
[ "$OOM" = "false" ]

echo "=== Standalone runtime invariant ==="
LOGS="$(docker compose logs --since=10m --no-color admin-web)"
if printf '%s\n' "$LOGS" | grep -q 'next start.*standalone'; then
  echo "ERROR: admin-web is still launched with next start under standalone output."
  return 1 2>/dev/null || false
fi
echo "PASS standalone runtime warning absent"

JAR="/tmp/zabisa-admin-runtime-cookie.txt"
LOGIN_JSON="/tmp/zabisa-admin-runtime-login.json"
LOGIN_RESPONSE="/tmp/zabisa-admin-runtime-login-response.json"
SESSION_RESPONSE="/tmp/zabisa-admin-runtime-session-response.json"
rm -f "$JAR" "$LOGIN_JSON" "$LOGIN_RESPONSE" "$SESSION_RESPONSE"

# Keep the Backoffice BFF login request aligned with the published API contract:
# LoginRequest has only email + password.
python3 - "$LOGIN_JSON" "$EMAIL" "$PASSWORD" <<'PY'
import json, sys
path, email, password = sys.argv[1:]
with open(path, "w", encoding="utf-8") as f:
    json.dump({"email": email, "password": password}, f, separators=(",", ":"))
PY

echo "=== Authenticated Backoffice login ==="
LOGIN_CODE="$(
  curl -sS --max-time 10 \
    -c "$JAR" \
    -o "$LOGIN_RESPONSE" \
    -w '%{http_code}' \
    -H 'Content-Type: application/json' \
    --data-binary "@$LOGIN_JSON" \
    "$BASE/api/auth/login"
)"
if [ "$LOGIN_CODE" != "200" ]; then
  echo "ERROR: Backoffice login returned HTTP $LOGIN_CODE"
  cat "$LOGIN_RESPONSE"
  return 1 2>/dev/null || false
fi
echo "PASS admin login HTTP 200"

SESSION_CODE="$(
  curl -sS --max-time 10 \
    -b "$JAR" \
    -o "$SESSION_RESPONSE" \
    -w '%{http_code}' \
    "$BASE/api/auth/session"
)"
if [ "$SESSION_CODE" != "200" ]; then
  echo "ERROR: authenticated session returned HTTP $SESSION_CODE"
  cat "$SESSION_RESPONSE"
  return 1 2>/dev/null || false
fi
echo "PASS authenticated session HTTP 200"

echo "=== Protected-page repetition ==="
COUNT=0
for i in $(seq 1 "$ITERATIONS"); do
  for path in access dashboard audit access; do
    COUNT=$((COUNT + 1))
    CODE="$(
      curl -sS --max-time 10 \
        -b "$JAR" \
        -o /dev/null \
        -w '%{http_code}' \
        "$BASE/$path?runtime_smoke=$i"
    )"
    if [ "$CODE" != "200" ]; then
      echo "ERROR: /$path iteration $i returned HTTP $CODE"
      docker compose logs --tail=120 --no-color admin-web
      return 1 2>/dev/null || false
    fi
  done
done
echo "PASS $COUNT authenticated protected-page requests"

curl -sS --max-time 10 -b "$JAR" -X POST -o /dev/null "$BASE/api/auth/logout" || true
rm -f "$JAR" "$LOGIN_JSON" "$LOGIN_RESPONSE" "$SESSION_RESPONSE"

echo "=== Final admin runtime state ==="
docker inspect "$CID" --format='status={{.State.Status}} health={{if .State.Health}}{{.State.Health.Status}}{{else}}n/a{{end}} restart_count={{.RestartCount}} oom={{.State.OOMKilled}}'

echo "=== ADMIN RUNTIME VERIFY: PASS ==="
