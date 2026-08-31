#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

echo "[hotfix-0.3.6] repository: $ROOT"
echo '[hotfix-0.3.6] verifying DB TLS + runtime/migrator boundary...'
./scripts/verify-db-security-boundary.sh

echo '[hotfix-0.3.6] running offline regression preflight...'
./scripts/preflight-offline.sh

echo '[hotfix-0.3.6] PASS: DB TLS + runtime/migrator source/manifests are internally consistent.'
echo '[hotfix-0.3.6] NOTE: no MySQL/Vault/Kubernetes mutation was performed by this apply script.'
echo '[hotfix-0.3.6] NEXT: bootstrap mysql-ca -> platform migrator SAs -> Vault migrator roles -> provision DB identities/KV -> GitOps sync.'
