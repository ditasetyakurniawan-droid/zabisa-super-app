#!/usr/bin/env bash

set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

fail() {
  echo "[dt457-harbor] ERROR: $*" >&2
  exit 1
}

expected_path='devops-apps/zabisa'
expected_prefix="harbor-dt.co.id/${expected_path}/"

grep -Fq "PROJECT = '${expected_path}'" Jenkinsfile \
  || fail 'Jenkins repository namespace mismatch'
grep -Fq 'PROJECT="${PROJECT:-devops-apps/zabisa}"' scripts/build-images.sh \
  || fail 'image builder repository namespace mismatch'
grep -Fq 'PROJECT="${PROJECT:-devops-apps/zabisa}"' scripts/update-gitops.sh \
  || fail 'GitOps renderer repository namespace mismatch'

expected_refs=16
actual_refs="$(
  grep -RhF -o "$expected_prefix" deploy/kubernetes/base |
    wc -l |
    tr -d ' '
)"
[[ "$actual_refs" == "$expected_refs" ]] \
  || fail "expected $expected_refs nested image references, found $actual_refs"

names='api-gateway|identity|content|student|tahfidz|academic|donation|notification|admin-web'
if grep -RInE "harbor-dt\.co\.id/devops-apps/(${names}):" \
  Jenkinsfile scripts deploy/kubernetes/base docs/deployment 2>/dev/null; then
  fail 'direct devops-apps/<image> reference remains'
fi

grep -Fq '$i == "digest:" && $(i + 1) ~ /^sha256:[0-9a-f]{64}$/' \
  scripts/build-images.sh \
  || fail 'Docker push digest parser is not position-independent'

if grep -Fq 'awk '\''$1 == "digest:" {print $2; exit}'\'' "$push_log"' \
  scripts/build-images.sh; then
  fail 'obsolete first-column-only digest parser remains'
fi

sample_digest='sha256:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef'
parsed="$(
  printf '%s\n' "test: digest: $sample_digest size: 1234" |
    awk '{
      for (i = 1; i < NF; i++) {
        if ($i == "digest:" && $(i + 1) ~ /^sha256:[0-9a-f]{64}$/) {
          print $(i + 1)
          exit
        }
      }
    }'
)"
[[ "$parsed" == "$sample_digest" ]] \
  || fail 'Docker push digest parser regression sample failed'

echo '[dt457-harbor] PASS: nested devops-apps/zabisa paths and Docker digest parsing are consistent.'
