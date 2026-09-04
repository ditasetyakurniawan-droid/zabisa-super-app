#!/usr/bin/env bash
set -Eeuo pipefail
set +x

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

KUBECTL_BIN="${KUBECTL:-kubectl}"
NAMESPACE='zabisa-app'
IMAGE='mysql@sha256:b3b90af2a6552ae30c266fdb7d5dd55f3afb72404bb78d37fe8a23eb857fd3fb'
CURRENT_POD=''

cleanup() {
  local rc=$?
  if [[ -n "$CURRENT_POD" ]]; then
    "$KUBECTL_BIN" -n "$NAMESPACE" delete pod "$CURRENT_POD" \
      --ignore-not-found --wait=false >/dev/null 2>&1 || true
  fi
  exit "$rc"
}
trap cleanup EXIT INT TERM

command -v "$KUBECTL_BIN" >/dev/null 2>&1 || {
  echo '[mysql-canary] ERROR: kubectl is required' >&2
  exit 1
}

run_probe() {
  local kind="$1"
  local service_account role secret_path

  if [[ "$kind" == 'runtime' ]]; then
    service_account='zabisa-identity'
    role='app-zabisa-identity-dt'
    secret_path='kv/data/zabisa/dt/identity/database'
  else
    service_account='zabisa-identity-migrator'
    role='app-zabisa-identity-migrator-dt'
    secret_path='kv/data/zabisa/dt/identity/migrator'
  fi

  CURRENT_POD="zabisa-mysql-${kind}-canary"
  if "$KUBECTL_BIN" -n "$NAMESPACE" get pod "$CURRENT_POD" >/dev/null 2>&1; then
    echo "[mysql-canary] ERROR: existing pod must be inspected first: $NAMESPACE/$CURRENT_POD" >&2
    exit 1
  fi

  sed \
    -e "s|__POD__|$CURRENT_POD|g" \
    -e "s|__SA__|$service_account|g" \
    -e "s|__ROLE__|$role|g" \
    -e "s|__SECRET_PATH__|$secret_path|g" \
    -e "s|__KIND__|$kind|g" \
    -e "s|__IMAGE__|$IMAGE|g" \
    deploy/kubernetes/canary/mysql-credential-canary.yaml |
    "$KUBECTL_BIN" apply -f - >/dev/null

  echo "[mysql-canary] waiting for $kind credential probe"
  if ! "$KUBECTL_BIN" -n "$NAMESPACE" wait \
    --for=condition=Ready "pod/$CURRENT_POD" --timeout=180s >/dev/null; then
    "$KUBECTL_BIN" -n "$NAMESPACE" get pod "$CURRENT_POD" -o wide >&2 || true
    "$KUBECTL_BIN" -n "$NAMESPACE" describe pod "$CURRENT_POD" |
      sed -n '/Events:/,$p' >&2 || true
    exit 1
  fi

  logs="$($KUBECTL_BIN -n "$NAMESPACE" logs "$CURRENT_POD" -c mysql-canary --tail=20)"
  grep -Fqx "[mysql-canary] $kind authentication passed" <<<"$logs" || {
    echo "[mysql-canary] ERROR: $kind probe did not report success" >&2
    printf '%s\n' "$logs" >&2
    exit 1
  }

  "$KUBECTL_BIN" -n "$NAMESPACE" get pod "$CURRENT_POD" -o json |
    python3 -c '
import json, sys
p = json.load(sys.stdin)
a = p["metadata"].get("annotations", {})
assert a.get("vault.hashicorp.com/agent-inject-status") == "injected"
assert "vault-agent-init" in [c["name"] for c in p["spec"].get("initContainers", [])]
'

  echo "[mysql-canary] PASS: $kind Vault credential authenticated to MySQL from an allowed cluster pod"
  "$KUBECTL_BIN" -n "$NAMESPACE" delete pod "$CURRENT_POD" --wait=true >/dev/null
  CURRENT_POD=''
}

"$KUBECTL_BIN" -n "$NAMESPACE" get secret vault-ca mysql-ca >/dev/null
"$KUBECTL_BIN" -n "$NAMESPACE" get service db-dt >/dev/null
run_probe runtime
run_probe migrator

echo '[mysql-canary] PASS: runtime and migrator credential synchronization is proven in-cluster.'
