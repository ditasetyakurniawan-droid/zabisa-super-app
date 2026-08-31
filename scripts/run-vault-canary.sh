#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

KUBECTL_BIN="${KUBECTL:-kubectl}"
NAMESPACE="zabisa-app"
POD="zabisa-vault-canary"
POLICY_NAME="zabisa-canary"
ROLE_NAME="zabisa-canary"
KV_PATH="zabisa/dt/canary"
MANIFEST="deploy/kubernetes/canary/vault-canary.yaml"
POLICY_FILE="deploy/vault/canary/zabisa-canary.hcl"
CLEANUP_REQUIRED=0
SUCCESS=0

command -v "$KUBECTL_BIN" >/dev/null 2>&1 || { echo "[canary] ERROR: kubectl executable not found: $KUBECTL_BIN" >&2; exit 1; }
command -v vault >/dev/null 2>&1 || { echo '[canary] ERROR: vault CLI is required' >&2; exit 1; }
: "${VAULT_ADDR:?set VAULT_ADDR to the active local Vault endpoint/port-forward}"

cleanup() {
  rc=$?
  if (( CLEANUP_REQUIRED )); then
    echo '[canary] cleanup: deleting temporary Kubernetes pod...'
    "$KUBECTL_BIN" -n "$NAMESPACE" delete pod "$POD" --ignore-not-found --wait=false >/dev/null 2>&1 || true
    echo '[canary] cleanup: deleting temporary Vault Kubernetes role + policy + KV metadata...'
    vault delete "auth/kubernetes/role/${ROLE_NAME}" >/dev/null 2>&1 || true
    vault policy delete "$POLICY_NAME" >/dev/null 2>&1 || true
    vault kv metadata delete -mount=kv "$KV_PATH" >/dev/null 2>&1 || true
  fi
  if (( SUCCESS )); then
    echo '[canary] CLEANUP PASS: temporary pod, Vault role, policy and KV metadata removal requested.'
  elif (( rc != 0 )); then
    echo "[canary] FAIL: canary aborted with exit code ${rc}; cleanup was attempted." >&2
  fi
}
trap cleanup EXIT

./scripts/verify-vault-canary.sh
./scripts/verify-cluster-vault-compat.sh

vault status >/dev/null
vault token lookup >/dev/null

"$KUBECTL_BIN" get ns "$NAMESPACE" >/dev/null
"$KUBECTL_BIN" -n "$NAMESPACE" get sa zabisa-api-gateway >/dev/null
"$KUBECTL_BIN" -n "$NAMESPACE" get secret vault-ca -o json \
  | python3 -c 'import json,sys; d=json.load(sys.stdin).get("data",{}); assert sorted(d.keys())==["ca.crt"] and bool(d["ca.crt"])'

# Refuse to overwrite any unexpected pre-existing canary control-plane objects.
if vault policy read "$POLICY_NAME" >/dev/null 2>&1; then
  echo "[canary] ERROR: Vault policy ${POLICY_NAME} already exists; inspect/remove it before running this temporary test" >&2
  exit 1
fi
if vault read "auth/kubernetes/role/${ROLE_NAME}" >/dev/null 2>&1; then
  echo "[canary] ERROR: Vault role ${ROLE_NAME} already exists; inspect/remove it before running this temporary test" >&2
  exit 1
fi
if vault kv metadata get -mount=kv "$KV_PATH" >/dev/null 2>&1; then
  echo "[canary] ERROR: KV path kv/${KV_PATH} already exists; refusing to overwrite it" >&2
  exit 1
fi
if "$KUBECTL_BIN" -n "$NAMESPACE" get pod "$POD" >/dev/null 2>&1; then
  echo "[canary] ERROR: pod ${NAMESPACE}/${POD} already exists; inspect/remove it before running this temporary test" >&2
  exit 1
fi

CLEANUP_REQUIRED=1

echo '[canary] creating temporary read-only workload policy...'
vault policy write "$POLICY_NAME" "$POLICY_FILE" >/dev/null

echo '[canary] creating temporary Kubernetes auth role bound to zabisa-api-gateway in zabisa-app...'
vault write "auth/kubernetes/role/${ROLE_NAME}" \
  bound_service_account_names="zabisa-api-gateway" \
  bound_service_account_namespaces="$NAMESPACE" \
  policies="$POLICY_NAME" \
  audience="vault" \
  ttl="10m" >/dev/null

echo '[canary] writing non-sensitive temporary KV marker...'
vault kv put -mount=kv "$KV_PATH" marker="zabisa-vault-canary-ok" >/dev/null

echo '[canary] creating one init-only Vault Agent pod...'
"$KUBECTL_BIN" apply -f "$MANIFEST" >/dev/null

if ! "$KUBECTL_BIN" -n "$NAMESPACE" wait --for=condition=Ready "pod/${POD}" --timeout=120s >/dev/null; then
  echo '[canary] ERROR: pod did not become Ready; sanitized status follows' >&2
  "$KUBECTL_BIN" -n "$NAMESPACE" get pod "$POD" -o wide >&2 || true
  "$KUBECTL_BIN" -n "$NAMESPACE" get pod "$POD" -o json \
    | python3 -c 'import json,sys; p=json.load(sys.stdin); print("phase="+str(p.get("status",{}).get("phase"))); print("reason="+str(p.get("status",{}).get("reason"))); print("message="+str(p.get("status",{}).get("message"))); print("init="+",".join(c.get("name","") for c in p.get("spec",{}).get("initContainers",[]))); print("containers="+",".join(c.get("name","") for c in p.get("spec",{}).get("containers",[])))' >&2 || true
  exit 1
fi

"$KUBECTL_BIN" -n "$NAMESPACE" get pod "$POD" -o json | python3 -c 'import json,sys; p=json.load(sys.stdin); a=p["metadata"].get("annotations",{}); init=[c["name"] for c in p["spec"].get("initContainers",[])]; containers=[c["name"] for c in p["spec"].get("containers",[])]; assert a.get("vault.hashicorp.com/agent-inject-status")=="injected", "injector status annotation missing"; assert "vault-agent-init" in init, f"vault-agent-init missing: {init}"; assert "vault-agent" not in containers, f"pre-populate-only should not inject sidecar: {containers}"; assert containers==["canary"], f"unexpected application containers: {containers}"'

LOGS="$($KUBECTL_BIN -n "$NAMESPACE" logs "$POD" -c canary --tail=20 2>/dev/null || true)"
if ! grep -q '^\[zabisa-canary\] secret-file verification passed$' <<<"$LOGS"; then
  echo '[canary] ERROR: application container did not confirm secret-file/mode verification' >&2
  exit 1
fi

MODE="$($KUBECTL_BIN -n "$NAMESPACE" exec "$POD" -c canary -- /bin/sh -ec "stat -c '%a' /vault/secrets/canary" 2>/dev/null)"
[[ "$MODE" == "400" ]] || { echo "[canary] ERROR: rendered file mode is ${MODE}, expected 400" >&2; exit 1; }

echo '[canary] OK: Kubernetes ServiceAccount JWT authenticated to Vault with audience=vault'
echo '[canary] OK: Vault Agent Injector used TLS vault-ca and rendered the temporary KV value'
echo '[canary] OK: init-only injection produced /vault/secrets/canary with mode 0400'
echo '[canary] OK: no Vault Agent sidecar remains in the running canary pod'
echo '[canary] PASS: Zabisa Vault Agent end-to-end canary succeeded.'
SUCCESS=1
