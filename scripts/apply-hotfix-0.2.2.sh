#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

echo "[hotfix-0.2.2] repository: $ROOT"
echo "[hotfix-0.2.2] verifying deterministic Node dependency baseline..."
node ./scripts/verify-node-lockfile.mjs

if grep -nE 'npm (install|i)( |$)' Jenkinsfile apps/admin-web/Dockerfile Makefile scripts/bootstrap-mobile-native.sh README.md; then
  echo "[hotfix-0.2.2] ERROR: non-deterministic npm install remains in build/bootstrap path" >&2
  exit 1
fi

echo "[hotfix-0.2.2] OK: build/bootstrap paths use npm ci"
./scripts/preflight-offline.sh

echo "[hotfix-0.2.2] PASS: deterministic Node CI/build hotfix is internally consistent."
echo "[hotfix-0.2.2] NOTE: no Kubernetes API access is required."
