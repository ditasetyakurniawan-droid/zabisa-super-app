#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

command -v vault >/dev/null 2>&1 || { echo '[vault-migrator-auth] ERROR: vault CLI is required' >&2; exit 1; }
: "${VAULT_ADDR:?set VAULT_ADDR to the existing Vault endpoint reachable from this host}"
vault status >/dev/null

services=(identity content student tahfidz academic donation notification)
for svc in "${services[@]}"; do
  policy="zabisa-${svc}-migrator-dt"
  role="app-zabisa-${svc}-migrator-dt"
  sa="zabisa-${svc}-migrator"
  file="deploy/vault/policies/${policy}.hcl"
  echo "[vault-migrator-auth] writing policy ${policy}"
  vault policy write "$policy" "$file"
  echo "[vault-migrator-auth] writing Kubernetes role ${role}"
  vault write "auth/kubernetes/role/${role}" \
    bound_service_account_names="$sa" \
    bound_service_account_namespaces="zabisa-app" \
    policies="$policy" \
    audience="vault" \
    ttl="30m" >/dev/null
done

echo '[vault-migrator-auth] PASS: 7 migration-only policies + Kubernetes auth roles configured.'
echo '[vault-migrator-auth] NOTE: no KV secret values were written.'
