#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
fail(){ echo "[db-security] ERROR: $*" >&2; exit 1; }
pass(){ echo "[db-security] OK: $*"; }

db_services=(identity content student tahfidz academic donation notification)

# Source-mode split: DT runtime must not execute embedded migrations.
grep -q 'ModeMigrate.*= "migrate"' packages/go/platform/config/config.go || fail 'APP_MODE migrate support missing'
grep -q 'ModeServe.*= "serve"' packages/go/platform/config/config.go || fail 'APP_MODE serve support missing'
grep -q 'MYSQL_TLS_MODE=disabled is not allowed outside local development' packages/go/platform/config/config.go || fail 'non-local plaintext DB fail-close missing'
grep -q 'VerifyConnection' packages/go/platform/database/mysql.go || fail 'pinned-CA verification hook missing'
grep -q 'tls.VersionTLS12' packages/go/platform/database/mysql.go || fail 'TLS 1.2 minimum missing'
if grep -q 'tls=skip-verify' packages/go/platform/config/config.go packages/go/platform/database/mysql.go; then
  fail 'skip-verify DSN is forbidden'
fi
pass 'Go DB client requires explicit non-local TLS and pinned-CA certificate-chain verification'

for svc in "${db_services[@]}"; do
  f="services/${svc}/main.go"
  grep -q 'cfg.ShouldMigrate()' "$f" || fail "$svc does not gate migrations by APP_MODE"
  grep -q 'cfg.MigrateOnly()' "$f" || fail "$svc lacks migrate-only exit path"
  k="deploy/kubernetes/base/${svc}.yaml"
  grep -A1 -q 'name: APP_MODE' "$k" || fail "$svc runtime APP_MODE missing"
  grep -A1 'name: APP_MODE' "$k" | grep -q 'value: serve' || fail "$svc runtime must use APP_MODE=serve"
  grep -A1 'name: MYSQL_TLS_MODE' "$k" | grep -q 'value: verify-ca' || fail "$svc runtime must use MySQL verify-ca"
  grep -q 'value: /mysql/tls/ca.pem' "$k" || fail "$svc MySQL CA path missing"
  grep -q 'secretName: mysql-ca' "$k" || fail "$svc mysql-ca mount missing"
done
pass '7 DT runtime Deployments use APP_MODE=serve and cannot auto-run schema migrations'

mig='deploy/kubernetes/base/migrations.yaml'
[[ -f "$mig" ]] || fail 'migration Jobs manifest missing'
job_count="$(grep -c '^kind: Job$' "$mig" || true)"
[[ "$job_count" == "7" ]] || fail "expected 7 migration Jobs, found $job_count"
for svc in "${db_services[@]}"; do
  grep -q "name: ${svc}-migrate" "$mig" || fail "$svc migration Job missing"
  grep -q "serviceAccountName: zabisa-${svc}-migrator" "$mig" || fail "$svc migration SA missing"
  grep -q "kv/data/zabisa/dt/${svc}/migrator" "$mig" || fail "$svc migration Vault path missing"
done
grep -q 'argocd.argoproj.io/hook: PreSync' "$mig" || fail 'migration Jobs are not ArgoCD PreSync hooks'
[[ "$(grep -c 'argocd.argoproj.io/sync-wave:' "$mig")" == "7" ]] || fail 'every migration Job must have an explicit sync wave'
[[ "$(grep -c 'backoffLimit: 0' "$mig")" == "7" ]] || fail 'migration Jobs must fail closed without automatic retry'
grep -q 'value: migrate' "$mig" || fail 'migration Jobs do not use APP_MODE=migrate'
grep -q 'value: verify-ca' "$mig" || fail 'migration Jobs do not require MySQL verify-ca'
if grep -Eq 'JWT_SIGNING_KEY|INTERNAL_SERVICE_KEY|/shared/runtime' "$mig"; then
  fail 'migration Jobs receive unnecessary application auth secrets'
fi
pass '7 ArgoCD PreSync migration Jobs use isolated DB-only identities'

for svc in "${db_services[@]}"; do
  grep -q "zabisa-${svc}-migrator" deploy/kubernetes/base/platform.yaml || fail "$svc migration ServiceAccount missing"
  p="deploy/vault/policies/zabisa-${svc}-migrator-dt.hcl"
  [[ -f "$p" ]] || fail "$svc migrator Vault policy missing"
  grep -q "kv/data/zabisa/dt/${svc}/migrator" "$p" || fail "$svc migrator policy path mismatch"
done
pass '7 migration ServiceAccounts + DB-only Vault policy boundaries exist'

if find deploy -type f \( -name '*.pem' -o -name '*.crt' -o -name '*.key' \) | grep -q .; then
  find deploy -type f \( -name '*.pem' -o -name '*.crt' -o -name '*.key' \) >&2
  fail 'MySQL/Vault certificate material must remain external to Git'
fi
pass 'CA certificate material remains external to Git and is bootstrapped separately'

echo '[db-security] PASS: DT database TLS + runtime/migrator privilege boundary is internally consistent.'
