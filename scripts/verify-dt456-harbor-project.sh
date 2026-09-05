#!/usr/bin/env bash

set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

fail() {
  echo "[dt456-harbor] ERROR: $*" >&2
  exit 1
}

if grep -RInE 'harbor-dt\.co\.id/zabisa(/|`|$)' \
  Jenkinsfile scripts deploy/kubernetes/base docs/deployment 2>/dev/null; then
  fail 'unauthorized Harbor project path remains'
fi

grep -Fq "PROJECT = 'devops-apps/zabisa'" Jenkinsfile \
  || fail 'Jenkins Harbor repository namespace is not devops-apps/zabisa'
grep -Fq 'PROJECT="${PROJECT:-devops-apps/zabisa}"' scripts/build-images.sh \
  || fail 'image builder default repository namespace is not devops-apps/zabisa'
grep -Fq 'PROJECT="${PROJECT:-devops-apps/zabisa}"' scripts/update-gitops.sh \
  || fail 'GitOps renderer default repository namespace is not devops-apps/zabisa'
grep -Fq 'harbor-dt\.co\.id/devops-apps/zabisa/' scripts/run-zabisa-jenkins-delivery.sh \
  || fail 'post-push Harbor digest verifier is not scoped to devops-apps/zabisa'

expected_refs=16
actual_refs="$(
  grep -RhF -o 'harbor-dt.co.id/devops-apps/zabisa/' deploy/kubernetes/base |
    wc -l |
    tr -d ' '
)"
[[ "$actual_refs" == "$expected_refs" ]] \
  || fail "expected $expected_refs devops-apps/zabisa manifest references, found $actual_refs"

for name in api-gateway identity content student tahfidz academic donation notification admin-web; do
  grep -RhFq "harbor-dt.co.id/devops-apps/zabisa/${name}:REPLACE_SHA" deploy/kubernetes/base \
    || fail "manifest registry reference missing for $name"
done

echo '[dt456-harbor] PASS: Jenkins, image build/push, GitOps render and all 16 manifests use devops-apps/zabisa.'
