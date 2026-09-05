#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

fail() { printf '[dt-access] ERROR: %s\n' "$*" >&2; exit 1; }
KUBECTL_BIN="${KUBECTL:-${KUBECTL_BIN:-kubectl}}"
command -v "$KUBECTL_BIN" >/dev/null 2>&1 || fail 'kubectl is required'
command -v adb >/dev/null 2>&1 || fail 'adb is required'

mapfile -t devices < <(adb devices | awk 'NR>1 && $2=="device" {print $1}')
(( ${#devices[@]} == 1 )) || fail "exactly one authorized Android device is required; found ${#devices[@]}"
serial="${devices[0]}"
api_pid=''
admin_pid=''

cleanup() {
  set +e
  [[ -n "$api_pid" ]] && kill "$api_pid" >/dev/null 2>&1
  [[ -n "$admin_pid" ]] && kill "$admin_pid" >/dev/null 2>&1
  adb -s "$serial" reverse --remove tcp:8088 >/dev/null 2>&1
}
trap cleanup EXIT INT TERM

for port in 18088 13001; do
  python3 - "$port" <<'PY'
import socket, sys
s = socket.socket()
try:
    s.bind(("127.0.0.1", int(sys.argv[1])))
except OSError as exc:
    raise SystemExit(f"local port {sys.argv[1]} is unavailable: {exc}")
finally:
    s.close()
PY
done

"$KUBECTL_BIN" -n zabisa-app port-forward service/api-gateway 18088:8080 &
api_pid=$!
"$KUBECTL_BIN" -n zabisa-app port-forward service/admin-web 13001:3000 &
admin_pid=$!
adb -s "$serial" reverse tcp:8088 tcp:18088 >/dev/null

for attempt in $(seq 1 30); do
  if curl -fsS http://127.0.0.1:18088/health/ready >/dev/null 2>&1 &&
    curl -fsS http://127.0.0.1:13001/login >/dev/null 2>&1; then
    break
  fi
  (( attempt < 30 )) || fail 'DT internal services did not become ready'
  sleep 1
done

adb -s "$serial" shell monkey -p id.or.subulussalam.zabisa -c android.intent.category.LAUNCHER 1 >/dev/null
command -v xdg-open >/dev/null 2>&1 && xdg-open http://127.0.0.1:13001/login >/dev/null 2>&1 || true

printf '\nDT internal access is active:\n'
printf '  Backoffice: http://127.0.0.1:13001/login\n'
printf '  Android   : 127.0.0.1:8088 -> API Gateway via adb reverse\n'
printf 'Press Enter to stop both port-forwards and remove adb reverse.\n'
IFS= read -r _
