#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
fail() { printf '[dt3-source] ERROR: %s\n' "$*" >&2; exit 1; }

migrations='deploy/kubernetes/base/migrations.yaml'
inventory='deploy/kubernetes/canary/mysql-schema-inventory.yaml'
runner='scripts/run-zabisa-mysql-schema-inventory.sh'
engine='packages/go/platform/migrate/migrate.go'
engine_test='packages/go/platform/migrate/migrate_test.go'

[[ "$(grep -c '^kind: Job$' "$migrations")" -eq 7 ]] || fail 'expected seven migration Jobs'

services=(content identity student tahfidz academic donation notification)
waves=(-70 -60 -50 -40 -30 -20 -10)
for index in "${!services[@]}"; do
  service="${services[$index]}"
  wave="${waves[$index]}"
  block="$(sed -n "/^  name: ${service}-migrate$/,/^---$/p" "$migrations")"
  grep -Fq "argocd.argoproj.io/sync-wave: \"$wave\"" <<<"$block" ||
    fail "$service migration wave must be $wave"
  grep -Fq 'backoffLimit: 0' <<<"$block" || fail "$service migration must not auto-retry"
done

if grep -Eq '^[[:space:]]*automated:' deploy/argocd/application.yaml; then
  fail 'ArgoCD automated sync must remain disabled during controlled delivery'
fi

grep -Fq 'mysql@sha256:' "$inventory" || fail 'schema inventory image must be digest-pinned'
grep -Fq 'SELECT COUNT(*) FROM information_schema.tables' "$inventory" || fail 'read-only table inventory query missing'
grep -Fq 'SELECT table_name FROM information_schema.tables' "$inventory" || fail 'read-only table-name query missing'
if grep -Ei 'mysql_query.*\b(INSERT|UPDATE|DELETE|ALTER|CREATE|DROP|TRUNCATE|REPLACE)\b' "$inventory"; then
  fail 'schema inventory template contains a SQL mutation verb'
fi

grep -Fq -- '--plan|--run' "$runner" || fail 'runner modes missing'
grep -Fq 'RUN-READ-ONLY-DT3-INVENTORY' "$runner" || fail 'explicit DT3 confirmation missing'
grep -Fq 'temporary canary pods remain' "$runner" || fail 'temporary-pod cleanup assertion missing'

grep -Fq 'SELECT GET_LOCK(?, ?)' "$engine" || fail 'migration advisory-lock acquisition missing'
grep -Fq 'SELECT RELEASE_LOCK(?)' "$engine" || fail 'migration advisory-lock release missing'
grep -Fq 'checksum CHAR(64) NOT NULL' "$engine" || fail 'migration checksum column missing'
grep -Fq 'migration checksum drift' "$engine" || fail 'checksum-drift fail-closed path missing'
grep -Fq 'explicit operator baselining is required' "$engine" || fail 'legacy migration records must fail closed'
grep -Fq 'TestRepositoryMigrationStatementShapes' "$engine_test" || fail 'repository migration-shape test missing'
grep -Fq 'want 18' "$engine_test" || fail 'repository migration-count assertion missing'

echo '[dt3-source] PASS: manual ArgoCD control, sequential waves, zero retries, read-only inventory, advisory locking, checksums and reviewed SQL-shape invariants.'
