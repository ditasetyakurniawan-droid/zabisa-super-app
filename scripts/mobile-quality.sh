#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd); cd "$ROOT"
echo '=== TypeScript ==='; npm run typecheck --workspace=@zabisa/mobile
echo '=== ESLint ==='; npm run lint --workspace=@zabisa/mobile
echo '=== Jest + Coverage ==='; npm test --workspace=@zabisa/mobile
echo '=== Guardian API E2E ==='; npm run mobile:e2e:guardian
echo '=== MOBILE QUALITY: PASS ==='
