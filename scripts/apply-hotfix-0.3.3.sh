#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
echo "[hotfix-0.3.3] repository: $ROOT"
echo '[hotfix-0.3.3] verifying temporary Vault Agent canary overlay...'
./scripts/verify-vault-canary.sh
echo '[hotfix-0.3.3] running offline regression preflight...'
./scripts/preflight-offline.sh
echo '[hotfix-0.3.3] PASS: canary overlay is internally consistent.'
echo '[hotfix-0.3.3] NOTE: no Vault/Kubernetes mutation was performed by this apply script.'
echo '[hotfix-0.3.3] Run scripts/run-vault-canary.sh explicitly to execute the temporary end-to-end test.'
