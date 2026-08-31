#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

echo "[hotfix-0.3] repository: $ROOT"
echo '[hotfix-0.3] verifying Vault Agent Injector baseline...'
./scripts/verify-vault-injector.sh

echo '[hotfix-0.3] running offline repository/deployment preflight...'
./scripts/preflight-offline.sh

git diff --check 2>/dev/null || true

echo '[hotfix-0.3] PASS: Vault Agent Injector source/manifests are internally consistent.'
echo '[hotfix-0.3] NOTE: no Vault policy/role/KV mutation and no Kubernetes deployment was performed.'
echo '[hotfix-0.3] FIRST DEPLOYMENT ORDER: configure Vault KV -> policies/roles -> create namespace/SAs -> copy vault-ca -> ArgoCD sync.'
