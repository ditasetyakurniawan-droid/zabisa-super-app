#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
chmod +x scripts/*.sh

echo "[hotfix-0.2.3] repository: $ROOT"
echo '[hotfix-0.2.3] verifying immutable 9-image pipeline...'
./scripts/verify-image-pipeline.sh

echo '[hotfix-0.2.3] running offline repository/deployment preflight...'
./scripts/preflight-offline.sh

git diff --check

echo '[hotfix-0.2.3] PASS: immutable image + GitOps render baseline is internally consistent.'
echo '[hotfix-0.2.3] NOTE: no Kubernetes API, Harbor login, registry push or GitOps repo publication was attempted.'
