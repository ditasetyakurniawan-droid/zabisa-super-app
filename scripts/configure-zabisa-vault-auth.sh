#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

command -v vault >/dev/null 2>&1 || { echo '[vault-auth] ERROR: vault CLI is required' >&2; exit 1; }
: "${VAULT_ADDR:?set VAULT_ADDR to the existing Vault endpoint reachable from this host}"

# Do not accept a token argument: use the Vault CLI token helper or VAULT_TOKEN supplied by the operator.
vault status >/dev/null

declare -a services=(api-gateway identity content student tahfidz academic donation notification)
for svc in "${services[@]}"; do
  policy="zabisa-${svc}-dt"
  role="app-zabisa-${svc}-dt"
  sa="zabisa-${svc}"
  file="deploy/vault/policies/${policy}.hcl"
  echo "[vault-auth] writing policy ${policy}"
  vault policy write "$policy" "$file"
  echo "[vault-auth] writing Kubernetes role ${role}"
  vault write "auth/kubernetes/role/${role}" \
    bound_service_account_names="$sa" \
    bound_service_account_namespaces="zabisa-app" \
    policies="$policy" \
    audience="vault" \
    ttl="1h" >/dev/null
done

echo '[vault-auth] PASS: Zabisa DT policies + Kubernetes auth roles configured.'
echo '[vault-auth] NOTE: this script does not write any KV secret values.'
