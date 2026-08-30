#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"
echo '== Go 1.26.7 dependency + test =='
docker run --rm -v "$ROOT:/src" -w /src golang:1.26.7-alpine sh -c 'export PATH=/usr/local/go/bin:$PATH; go version; go mod tidy; go test ./...'
echo '== Build and start full local stack =='
docker rm -f zabisa-admin-web >/dev/null 2>&1 || true
docker compose down --remove-orphans
docker compose build
docker compose up -d
echo '== E2E vertical-slice verification =='
./scripts/verify-phase2.sh
echo '== Service status =='
docker compose ps
