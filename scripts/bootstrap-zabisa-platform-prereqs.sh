#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
KUBECTL_BIN="${KUBECTL:-kubectl}"
SRC_NS="${1:-}"
[[ -n "$SRC_NS" ]] || { echo "usage: $0 <existing-namespace-containing-vault-ca>" >&2; exit 64; }
command -v "$KUBECTL_BIN" >/dev/null 2>&1 || { echo "[bootstrap] ERROR: kubectl executable not found: $KUBECTL_BIN" >&2; exit 1; }

./scripts/verify-cluster-vault-compat.sh

echo '[bootstrap] applying namespace, per-workload ServiceAccounts and deny-by-default NetworkPolicies only...'
"$KUBECTL_BIN" apply -f deploy/kubernetes/base/platform.yaml

echo '[bootstrap] copying the CA-only Vault trust secret without printing its data...'
./scripts/bootstrap-zabisa-vault-ca.sh "$SRC_NS" zabisa-app

echo '[bootstrap] verifying bootstrap resources...'
"$KUBECTL_BIN" get ns zabisa-app >/dev/null
"$KUBECTL_BIN" -n zabisa-app get sa zabisa-api-gateway zabisa-identity zabisa-content zabisa-student zabisa-tahfidz zabisa-academic zabisa-donation zabisa-notification zabisa-admin-web zabisa-identity-migrator zabisa-content-migrator zabisa-student-migrator zabisa-tahfidz-migrator zabisa-academic-migrator zabisa-donation-migrator zabisa-notification-migrator >/dev/null
"$KUBECTL_BIN" -n zabisa-app get secret vault-ca -o json \
  | python3 -c 'import json,sys; d=json.load(sys.stdin).get("data",{}); assert sorted(d.keys())==["ca.crt"] and bool(d["ca.crt"]), "vault-ca/ca.crt missing or unexpected keys present"' \
  || { echo '[bootstrap] ERROR: vault-ca/ca.crt validation failed' >&2; exit 1; }

echo '[bootstrap] PASS: Zabisa namespace/Vault Kubernetes prerequisites exist. No application Deployment was created.'
