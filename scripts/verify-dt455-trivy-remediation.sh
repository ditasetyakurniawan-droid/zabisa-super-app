#!/usr/bin/env bash

set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

fail() {
  echo "[dt455-trivy] ERROR: $*" >&2
  exit 1
}

grep -Eq '^[[:space:]]*golang\.org/x/crypto v0\.55\.0$' go.mod \
  || fail 'golang.org/x/crypto must be upgraded to v0.55.0'
grep -Eq '^[[:space:]]*golang\.org/x/sys v0\.47\.0 // indirect$' go.mod \
  || fail 'golang.org/x/sys must match the x/crypto v0.55.0 dependency'

for expected_sum in \
  'golang.org/x/crypto v0.55.0 h1:+KWHjbgOaAQ66dh/YlkZKHlz9ZUlq61AFirAR9ntP8M=' \
  'golang.org/x/crypto v0.55.0/go.mod h1:uq0V9dE/fzQuJtbnL+2EhWOE63vo164FY8xqEnV9xis=' \
  'golang.org/x/sys v0.47.0 h1:o7XGOvZQCADBQQ4Y7VNq2dRWQR7JmOUW8Kxx4ZsNgWs=' \
  'golang.org/x/sys v0.47.0/go.mod h1:4GL1E5IUh+htKOUEOaiffhrAeqysfVGipDYzABqnCmw='; do
  grep -Fxq "$expected_sum" go.sum || fail "module checksum missing: $expected_sum"
done

if grep -Eq 'golang\.org/x/(crypto v0\.33\.0|sys v0\.30\.0)' go.mod go.sum; then
  fail 'vulnerable Go module version remains'
fi

grep -Fq "'libcrypto3>=3.5.8-r0'" apps/admin-web/Dockerfile \
  || fail 'fixed Alpine libcrypto3 floor is missing'
grep -Fq "'libssl3>=3.5.8-r0'" apps/admin-web/Dockerfile \
  || fail 'fixed Alpine libssl3 floor is missing'
grep -Fq 'rm -rf /usr/local/lib/node_modules/npm' apps/admin-web/Dockerfile \
  || fail 'npm build tooling is still retained in the Admin runtime image'
grep -Fq '/usr/local/lib/node_modules/corepack' apps/admin-web/Dockerfile \
  || fail 'Corepack build tooling is still retained in the Admin runtime image'

runtime_stage="$(sed -n '/^FROM .* AS run$/,$p' apps/admin-web/Dockerfile)"
if grep -Eq 'npm (ci|install|run)' <<<"$runtime_stage"; then
  fail 'Admin runtime stage still executes npm tooling'
fi
grep -Fq 'CMD ["node", "apps/admin-web/server.js"]' <<<"$runtime_stage" \
  || fail 'Admin runtime must start the standalone server directly with Node'

echo '[dt455-trivy] PASS: Go crypto, Alpine OpenSSL and Admin runtime npm CVE sources are remediated.'
