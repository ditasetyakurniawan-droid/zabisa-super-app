#!/usr/bin/env bash
set -Eeuo pipefail

fail() {
  printf '[dt2-source] ERROR: %s\n' "$*" >&2
  exit 1
}

BOOTSTRAP='scripts/bootstrap-zabisa-dt2-vault.sh'
RUNNER='scripts/run-zabisa-mysql-credential-canary.sh'
MANIFEST='deploy/kubernetes/canary/mysql-credential-canary.yaml'

for file in "$BOOTSTRAP" "$RUNNER" "$MANIFEST" \
  docs/deployment/PHASE-DT2-VAULT-CA-CREDENTIAL-CANARY.md; do
  [[ -s "$file" ]] || fail "missing file: $file"
done

bash -n "$BOOTSTRAP" "$RUNNER" || fail 'shell syntax validation failed'

grep -Fq 'zabisa.network/mysql-access: "true"' "$MANIFEST" ||
  fail 'canary must opt into the existing MySQL egress policy'
grep -Fq 'zabisa.network/vault-access: "true"' "$MANIFEST" ||
  fail 'canary must opt into the existing Vault egress policy'
grep -Fq 'vault.hashicorp.com/agent-pre-populate-only: "true"' "$MANIFEST" ||
  fail 'canary must use init-only Vault injection'
grep -Fq 'serviceAccountName: __SA__' "$MANIFEST" ||
  fail 'canary ServiceAccount placeholder missing'
grep -Fq -- '--ssl-mode=VERIFY_CA' "$MANIFEST" ||
  fail 'canary must verify the MySQL CA'
grep -Fq 'secretName: mysql-ca' "$MANIFEST" ||
  fail 'canary MySQL CA mount missing'
grep -Fq 'image: __IMAGE__' "$MANIFEST" ||
  fail 'canary image placeholder missing'
grep -Fq "IMAGE='mysql@sha256:" "$RUNNER" ||
  fail 'canary MySQL image must be digest pinned'
grep -Fq 'waiting for $kind authentication result' "$RUNNER" ||
  fail 'canary must wait for the authentication result, not only Pod Ready'
grep -Fq 'probe_passed=false' "$RUNNER" ||
  fail 'canary authentication-result polling guard missing'
if grep -Fq -- '--for=condition=Ready' "$RUNNER"; then
  fail 'Pod Ready is not a sufficient credential-canary success condition'
fi
grep -Fq 'bound_service_account_namespaces="zabisa-app"' \
  scripts/configure-zabisa-vault-auth.sh ||
  fail 'runtime Vault roles must remain namespace bounded'
grep -Fq 'bound_service_account_namespaces="zabisa-app"' \
  scripts/configure-zabisa-vault-migrator-auth.sh ||
  fail 'migrator Vault roles must remain namespace bounded'

if grep -Eq "MYSQL_ACCOUNT_NETWORKS=.*(%|0\.0\.0\.0/0)" "$BOOTSTRAP" "$RUNNER"; then
  fail 'DT2 must never widen MySQL account source boundaries'
fi

echo '[dt2-source] PASS: DT2 Vault/CA and in-cluster credential-canary invariants.'
