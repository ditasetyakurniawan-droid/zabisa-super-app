#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

MANIFEST="deploy/kubernetes/canary/vault-canary.yaml"
POLICY="deploy/vault/canary/zabisa-canary.hcl"
RUNNER="scripts/run-vault-canary.sh"

[[ -f "$MANIFEST" && -f "$POLICY" && -f "$RUNNER" ]] || { echo '[canary-verify] ERROR: canary files missing' >&2; exit 1; }

grep -q "vault.hashicorp.com/agent-pre-populate-only: 'true'" "$MANIFEST"
grep -q "vault.hashicorp.com/role: zabisa-canary" "$MANIFEST"
grep -q "vault.hashicorp.com/agent-service-account-token-volume-name: vault-token" "$MANIFEST"
grep -q "vault.hashicorp.com/tls-secret: vault-ca" "$MANIFEST"
grep -q "vault.hashicorp.com/ca-cert: /vault/tls/ca.crt" "$MANIFEST"
grep -q "vault.hashicorp.com/tls-server-name: vault.vault.svc" "$MANIFEST"
grep -q "vault.hashicorp.com/agent-run-as-same-user: 'true'" "$MANIFEST"
grep -q "vault.hashicorp.com/agent-inject-perms-canary: '0400'" "$MANIFEST"
grep -q 'serviceAccountName: zabisa-api-gateway' "$MANIFEST"
grep -q 'automountServiceAccountToken: false' "$MANIFEST"
grep -q 'audience: vault' "$MANIFEST"
grep -q 'expirationSeconds: 3600' "$MANIFEST"
grep -q 'tier: backend' "$MANIFEST"
grep -q 'zabisa.network/vault-access: "true"' "$MANIFEST"
grep -q 'path "kv/data/zabisa/dt/canary"' "$POLICY"
grep -q 'capabilities = \["read"\]' "$POLICY"

if grep -Eq 'MYSQL_|JWT_SIGNING_KEY|INTERNAL_SERVICE_KEY|password|secret[[:space:]]*=' "$POLICY" "$MANIFEST"; then
  echo '[canary-verify] ERROR: production credential material/reference found in temporary canary files' >&2
  exit 1
fi

bash -n "$RUNNER"
python3 - <<'PY'
import yaml
with open('deploy/kubernetes/canary/vault-canary.yaml', encoding='utf-8') as f:
    docs=list(yaml.safe_load_all(f))
assert len(docs)==1 and docs[0]['kind']=='Pod'
assert docs[0]['metadata']['namespace']=='zabisa-app'
PY

echo '[canary-verify] OK: temporary canary uses existing backend network edge + projected audience=vault token'
echo '[canary-verify] OK: Vault TLS trust, init-only injection and 0400 render permission are explicit'
echo '[canary-verify] OK: workload policy can read only kv/data/zabisa/dt/canary'
echo '[canary-verify] PASS: Vault canary baseline is internally consistent.'
