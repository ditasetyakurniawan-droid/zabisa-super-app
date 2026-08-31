#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

echo '[hotfix-0.3.2] verifying portable kubectl Secret inspection...'
bash scripts/verify-kubectl-json-portability.sh

echo '[hotfix-0.3.2] running offline regression preflight...'
bash scripts/preflight-offline.sh

echo '[hotfix-0.3.2] PASS: Vault CA bootstrap JSONPath portability hotfix is internally consistent.'
echo '[hotfix-0.3.2] Safe to rerun bootstrap-zabisa-platform-prereqs.sh; existing resources are idempotent.'
