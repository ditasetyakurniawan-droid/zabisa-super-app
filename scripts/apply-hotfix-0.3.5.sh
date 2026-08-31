#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
echo "[hotfix-0.3.5] repository: $ROOT"
echo '[hotfix-0.3.5] verifying BusyBox DNS probe portability...'
bash scripts/verify-db-dt-abstraction.sh
echo '[hotfix-0.3.5] running offline regression preflight...'
bash scripts/preflight-offline.sh
echo '[hotfix-0.3.5] PASS: db-dt runtime probe no longer treats BusyBox search-suffix NXDOMAIN exit status as failure.'
echo '[hotfix-0.3.5] NOTE: Service/EndpointSlice topology is unchanged; rerun apply-db-dt-abstraction.sh to perform DNS + TCP proof.'
