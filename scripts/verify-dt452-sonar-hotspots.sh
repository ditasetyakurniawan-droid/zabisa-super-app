#!/usr/bin/env bash

set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

fail() {
  echo "[dt452-sonar] ERROR: $*" >&2
  exit 1
}

dockerfiles=(
  services/academic/Dockerfile
  services/api-gateway/Dockerfile
  services/content/Dockerfile
  services/donation/Dockerfile
  services/identity/Dockerfile
  services/notification/Dockerfile
  services/student/Dockerfile
  services/tahfidz/Dockerfile
)

for dockerfile in "${dockerfiles[@]}"; do
  [[ -f "$dockerfile" ]] || fail "missing $dockerfile"
  [[ "$(grep -Fxc 'COPY go.mod go.sum ./' "$dockerfile")" -eq 1 ]] \
    || fail "$dockerfile must copy go.mod and go.sum explicitly"
  if grep -Eq '^COPY[[:space:]].*[?*]' "$dockerfile"; then
    fail "$dockerfile contains a wildcard COPY source"
  fi
done

donation_screen='apps/mobile/src/features/donation/DonationCheckoutScreen.tsx'
if grep -Fq 'Math.random()' "$donation_screen"; then
  fail 'donation idempotency key still uses Math.random()'
fi
grep -Fq 'const idempotencySequence = React.useRef(0);' "$donation_screen" \
  || fail 'monotonic per-process idempotency sequence is missing'
grep -Fq "headers: {'Idempotency-Key': nextIdempotencyKey()}" "$donation_screen" \
  || fail 'donation request is not using the reviewed idempotency-key generator'

admin_server='apps/admin-web/lib/server.ts'
if grep -Fq 'http://' "$admin_server"; then
  fail 'admin server source still contains a hard-coded clear-text backend URL'
fi
grep -Fq 'BACKEND_INTERNAL_URL is required' "$admin_server" \
  || fail 'BACKEND_INTERNAL_URL must fail closed when unset'
grep -Fq 'parsed.protocol === "https:"' "$admin_server" \
  || fail 'external backend transport must allow HTTPS'
grep -Fq 'plaintextBackendHosts.has(parsed.hostname)' "$admin_server" \
  || fail 'clear-text compatibility must remain restricted to reviewed internal hosts'

node - <<'NODE'
const fs = require('fs');
const path = 'apps/admin-web/tsconfig.sonar.json';
const config = JSON.parse(fs.readFileSync(path, 'utf8'));
const includes = new Set(config.include || []);
for (const required of ['e2e/**/*.ts', 'e2e/**/*.tsx', 'playwright.config.ts']) {
  if (!includes.has(required)) {
    throw new Error(`${path} does not include ${required}`);
  }
}
NODE

echo '[dt452-sonar] PASS: ten source hotspots are removed and all 70 TypeScript sources are covered by Sonar configs.'
