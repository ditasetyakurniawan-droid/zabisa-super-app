#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
fail() { printf '[dt3-source] ERROR: %s\n' "$*" >&2; exit 1; }

migrations='deploy/kubernetes/base/migrations.yaml'
inventory='deploy/kubernetes/canary/mysql-schema-inventory.yaml'
runner='scripts/run-zabisa-mysql-schema-inventory.sh'

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

echo '[dt3-source] PASS: manual ArgoCD control, sequential migration waves, zero automatic retry and read-only schema inventory invariants.'
