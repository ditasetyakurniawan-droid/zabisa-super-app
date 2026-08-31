#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

echo '[hotfix-0.3.1] verifying explicit kubectl binary selection...'
./scripts/verify-kubectl-override.sh

echo '[hotfix-0.3.1] running offline regression preflight...'
./scripts/preflight-offline.sh

echo '[hotfix-0.3.1] PASS: cluster scripts now honor KUBECTL=/path/to/kubectl.'
echo '[hotfix-0.3.1] Example: KUBECTL="$HOME/.local/bin/kubectl-zabisa" bash scripts/verify-cluster-vault-compat.sh'
