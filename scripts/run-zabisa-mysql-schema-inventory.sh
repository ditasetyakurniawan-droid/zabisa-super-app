#!/usr/bin/env bash
set -Eeuo pipefail
set +x

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

MODE="${1:---plan}"
KUBECTL_BIN="${KUBECTL:-kubectl}"
NAMESPACE='zabisa-app'
TEMPLATE='deploy/kubernetes/canary/mysql-schema-inventory.yaml'
CURRENT_POD=''

fail() { printf '[schema-inventory] ERROR: %s\n' "$*" >&2; exit 1; }

cleanup() {
  local rc=$?
  if [[ -n "$CURRENT_POD" ]]; then
    "$KUBECTL_BIN" -n "$NAMESPACE" delete pod "$CURRENT_POD" \
      --ignore-not-found --wait=false >/dev/null 2>&1 || true
  fi
  exit "$rc"
}
trap cleanup EXIT INT TERM

case "$MODE" in
  --plan|--run) ;;
  *) fail 'usage: run-zabisa-mysql-schema-inventory.sh --plan|--run' ;;
esac

[[ -f "$TEMPLATE" ]] || fail "template missing: $TEMPLATE"

services=(identity content student tahfidz academic donation notification)

render() {
  local service="$1"
  local database="${service}_db"
  local pod="zabisa-${service}-schema-inventory"
  sed \
    -e "s|__POD__|$pod|g" \
    -e "s|__SERVICE__|$service|g" \
    -e "s|__DATABASE__|$database|g" \
    -e "s|__SA__|zabisa-${service}-migrator|g" \
    -e "s|__ROLE__|app-zabisa-${service}-migrator-dt|g" \
    -e "s|__SECRET_PATH__|kv/data/zabisa/dt/${service}/migrator|g" \
    "$TEMPLATE"
}

if [[ "$MODE" == '--plan' ]]; then
  for service in "${services[@]}"; do
    render "$service" >/dev/null
    printf '[schema-inventory] PLAN: %-12s database=%s_db identity=zabisa-%s-migrator\n' \
      "$service" "$service" "$service"
  done
  echo '[schema-inventory] PLAN PASS: seven read-only schema probes rendered; no Kubernetes or MySQL mutation performed.'
  exit 0
fi

command -v "$KUBECTL_BIN" >/dev/null 2>&1 || fail 'kubectl is required for --run'

[[ "${DT3_CONFIRM:-}" == 'RUN-READ-ONLY-DT3-INVENTORY' ]] ||
  fail 'set DT3_CONFIRM=RUN-READ-ONLY-DT3-INVENTORY to authorize temporary read-only probes'

"$KUBECTL_BIN" -n "$NAMESPACE" get secret vault-ca mysql-ca >/dev/null
"$KUBECTL_BIN" -n "$NAMESPACE" get service db-dt >/dev/null

for service in "${services[@]}"; do
  CURRENT_POD="zabisa-${service}-schema-inventory"
  if "$KUBECTL_BIN" -n "$NAMESPACE" get pod "$CURRENT_POD" >/dev/null 2>&1; then
    fail "existing pod must be inspected first: $NAMESPACE/$CURRENT_POD"
  fi

  render "$service" | "$KUBECTL_BIN" create -f - >/dev/null
  echo "[schema-inventory] waiting for $service read-only result"
  result=''

  for attempt in $(seq 1 180); do
    logs="$(
      "$KUBECTL_BIN" -n "$NAMESPACE" logs "$CURRENT_POD" \
        -c schema-inventory --tail=100 2>/dev/null || true
    )"

    if grep -Fqx "[schema-inventory] $service completed" <<<"$logs"; then
      result="$logs"
      break
    fi

    phase="$(
      "$KUBECTL_BIN" -n "$NAMESPACE" get pod "$CURRENT_POD" \
        -o jsonpath='{.status.phase}' 2>/dev/null || true
    )"
    exit_code="$(
      "$KUBECTL_BIN" -n "$NAMESPACE" get pod "$CURRENT_POD" \
        -o jsonpath='{.status.containerStatuses[?(@.name=="schema-inventory")].state.terminated.exitCode}' \
        2>/dev/null || true
    )"

    if [[ -n "$exit_code" && "$exit_code" != 0 ]] || [[ "$phase" == Failed ]]; then
      printf '%s\n' "$logs" >&2
      fail "$service inventory pod failed (phase=${phase:-unknown}, exit=${exit_code:-unknown})"
    fi

    if (( attempt == 1 || attempt % 10 == 0 )); then
      echo "[schema-inventory] $service attempt $attempt: phase=${phase:-pending}"
    fi
    sleep 1
  done

  [[ -n "$result" ]] || fail "$service read-only inventory timed out"
  printf '%s\n' "$result"
  "$KUBECTL_BIN" -n "$NAMESPACE" delete pod "$CURRENT_POD" --wait=true >/dev/null
  CURRENT_POD=''
done

remaining="$(
  "$KUBECTL_BIN" -n "$NAMESPACE" get pods \
    -l 'zabisa.lifecycle=temporary-canary' --no-headers 2>/dev/null || true
)"
[[ -z "$remaining" ]] || fail "temporary canary pods remain: $remaining"

echo '[schema-inventory] PASS: seven database schemas inventoried read-only; temporary pods removed.'
