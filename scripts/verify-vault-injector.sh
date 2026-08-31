#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
fail(){ echo "[vault-verify] ERROR: $*" >&2; exit 1; }
pass(){ echo "[vault-verify] OK: $*"; }

services=(api-gateway identity content student tahfidz academic donation notification)
db_services=(identity content student tahfidz academic donation notification)

for svc in "${services[@]}"; do
  f="deploy/kubernetes/base/${svc}.yaml"
  grep -q 'vault.hashicorp.com/agent-inject: .true.' "$f" || fail "$svc missing injector annotation"
  grep -q "vault.hashicorp.com/role: app-zabisa-${svc}-dt" "$f" || fail "$svc Vault role mismatch"
  grep -q 'vault.hashicorp.com/agent-service-account-token-volume-name: vault-token' "$f" || fail "$svc token-volume annotation missing"
  grep -q 'vault.hashicorp.com/agent-run-as-same-user: .true.' "$f" || fail "$svc same-user annotation missing"
  grep -q 'audience: vault' "$f" || fail "$svc projected token audience mismatch"
  grep -q 'expirationSeconds: 3600' "$f" || fail "$svc projected token expiration mismatch"
  grep -q 'path: token' "$f" || fail "$svc projected token path mismatch"
  grep -q 'tls-secret: vault-ca' "$f" || fail "$svc vault-ca annotation missing"
  grep -q 'tls-server-name: vault.vault.svc' "$f" || fail "$svc TLS server name mismatch"
  grep -q 'runAsUser: 65532' "$f" || fail "$svc explicit distroless UID missing"
  grep -q 'zabisa.network/vault-access: .true.' "$f" || fail "$svc explicit Vault egress label missing"
  grep -q 'JWT_SIGNING_KEY_FILE' "$f" || fail "$svc JWT file env missing"
  grep -q 'INTERNAL_SERVICE_KEY_FILE' "$f" || fail "$svc internal key file env missing"
  if grep -q 'secretRef:' "$f"; then fail "$svc still references Kubernetes runtime Secret"; fi
  grep -q "serviceAccountName: zabisa-${svc}" "$f" || fail "$svc ServiceAccount mismatch"
done
pass '8 Go workloads use Vault Agent with per-workload ServiceAccounts and projected audience=vault tokens'

for svc in "${db_services[@]}"; do
  f="deploy/kubernetes/base/${svc}.yaml"
  grep -q 'MYSQL_USER_FILE' "$f" || fail "$svc MYSQL_USER_FILE missing"
  grep -q 'MYSQL_PASSWORD_FILE' "$f" || fail "$svc MYSQL_PASSWORD_FILE missing"
  grep -q "kv/data/zabisa/dt/${svc}/database" "$f" || fail "$svc DB Vault path mismatch"
done
pass '7 runtime services read per-context MySQL credentials from runtime-only Vault paths'

mig="deploy/kubernetes/base/migrations.yaml"
for svc in "${db_services[@]}"; do
  grep -q "name: ${svc}-migrate" "$mig" || fail "$svc migration Job missing"
  grep -q "serviceAccountName: zabisa-${svc}-migrator" "$mig" || fail "$svc migrator ServiceAccount mismatch"
  grep -q "vault.hashicorp.com/role: app-zabisa-${svc}-migrator-dt" "$mig" || fail "$svc migrator Vault role mismatch"
  grep -q "kv/data/zabisa/dt/${svc}/migrator" "$mig" || fail "$svc migrator Vault path mismatch"
  policy="deploy/vault/policies/zabisa-${svc}-migrator-dt.hcl"
  grep -q "path \"kv/data/zabisa/dt/${svc}/migrator\"" "$policy" || fail "$svc migrator policy path mismatch"
  grep -q 'capabilities = \["read"\]' "$policy" || fail "$svc migrator policy must be read-only"
done
if grep -Eq 'JWT_SIGNING_KEY|INTERNAL_SERVICE_KEY|/shared/runtime' "$mig"; then
  fail 'migration Jobs must not receive application JWT/internal-service secrets'
fi
pass '7 migration Jobs use isolated Vault identities and receive DB migrator credentials only'

if grep -q 'vault.hashicorp.com/agent-inject' deploy/kubernetes/base/admin-web.yaml; then
  fail 'admin-web must not receive Vault injection without a runtime secret requirement'
fi
pass 'admin-web remains Vault-free and uses no unnecessary credential identity'

grep -q 'name: allow-vault-egress' deploy/kubernetes/base/platform.yaml || fail 'Vault egress NetworkPolicy missing'
grep -q 'zabisa.network/vault-access: .true.' deploy/kubernetes/base/platform.yaml || fail 'Vault client selector missing'
grep -q 'kubernetes.io/metadata.name: vault' deploy/kubernetes/base/platform.yaml || fail 'Vault namespace selector missing'
grep -q 'port: 8200' deploy/kubernetes/base/platform.yaml || fail 'Vault TCP/8200 egress missing'
grep -q 'kubernetes.io/metadata.name: ingress-nginx' deploy/kubernetes/base/platform.yaml || fail 'existing ingress-nginx namespace selector missing'
grep -q 'zabisa.network/mysql-access: .true.' deploy/kubernetes/base/platform.yaml || fail 'MySQL client selector missing'
pass 'Calico edges are explicit for Vault, MySQL and existing ingress-nginx'

runtime_count="$(find deploy/vault/policies -maxdepth 1 -name 'zabisa-*-dt.hcl' ! -name '*-migrator-dt.hcl' | wc -l | tr -d ' ')"
migrator_count="$(find deploy/vault/policies -maxdepth 1 -name 'zabisa-*-migrator-dt.hcl' | wc -l | tr -d ' ')"
[[ "$runtime_count" == "8" ]] || fail "expected 8 runtime Vault policies, found $runtime_count"
[[ "$migrator_count" == "7" ]] || fail "expected 7 migrator Vault policies, found $migrator_count"
pass '8 runtime + 7 migrator least-privilege Vault policy files exist'

grep -q 'func secret' packages/go/platform/config/config.go || fail 'Go KEY_FILE loader missing'
grep -q 'os.ReadFile' packages/go/platform/config/config.go || fail 'Go secret file reader missing'
grep -q 'ValidateRuntime' packages/go/platform/config/config.go || fail 'Go runtime validation missing'
pass 'Go runtime supports KEY_FILE and fail-fast secret validation'

echo '[vault-verify] PASS: Vault Agent Injector baseline is internally consistent.'
