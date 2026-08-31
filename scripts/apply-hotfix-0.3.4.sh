#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
echo "[hotfix-0.3.4] repository: $ROOT"
bash scripts/verify-db-dt-abstraction.sh
echo '[hotfix-0.3.4] running offline regression preflight...'
bash scripts/preflight-offline.sh
echo '[hotfix-0.3.4] PASS: external MySQL DNS abstraction is internally consistent.'
echo '[hotfix-0.3.4] NOTE: no Kubernetes mutation was performed by this apply script.'
echo '[hotfix-0.3.4] Run scripts/apply-db-dt-abstraction.sh explicitly for the cluster mutation + DNS/TCP proof.'
