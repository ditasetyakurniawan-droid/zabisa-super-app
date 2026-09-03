#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [[ ! -d node_modules ]]; then
  echo '[quality] ERROR: node_modules is missing. Run npm ci --workspaces --include-workspace-root --no-audit --no-fund first.' >&2
  exit 1
fi

export CI=true
export NEXT_TELEMETRY_DISABLED=1

./scripts/preflight-offline.sh
./scripts/go-quality.sh

npm run node:lock:verify
npm run lint --workspace=@zabisa/admin-web -- --max-warnings=0
npm run lint --workspace=@zabisa/mobile -- --max-warnings=0
npm run typecheck --workspaces --if-present
npm run test --workspace=@zabisa/mobile
npm run build --workspace=@zabisa/admin-web
npm run audit:production

echo '[quality] PASS: repository quality gate'
