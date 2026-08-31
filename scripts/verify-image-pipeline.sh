#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
# shellcheck source=scripts/image-inventory.sh
source scripts/image-inventory.sh

fail() { echo "[image-verify] ERROR: $*" >&2; exit 1; }

[[ "${#ZABISA_IMAGE_NAMES[@]}" == "9" ]] || fail "expected 9 image targets, found ${#ZABISA_IMAGE_NAMES[@]}"

expected_refs=0
for name in "${ZABISA_IMAGE_NAMES[@]}"; do
  dockerfile="$(zabisa_dockerfile_for "$name")"
  manifest="deploy/kubernetes/base/$(zabisa_manifest_for "$name")"
  [[ -f "$dockerfile" ]] || fail "missing Dockerfile: $dockerfile"
  [[ -f "$manifest" ]] || fail "missing manifest: $manifest"
  grep -Fq "image: harbor-dt.co.id/zabisa/${name}:REPLACE_SHA" "$manifest" || fail "runtime manifest image placeholder mismatch for $name"
  expected="$(zabisa_expected_manifest_refs_for "$name")"
  count="$( (grep -RhF -o "harbor-dt.co.id/zabisa/${name}:REPLACE_SHA" deploy/kubernetes/base || true) | wc -l | tr -d ' ')"
  [[ "$count" == "$expected" ]] || fail "expected $expected manifest image refs for $name, found $count"
  expected_refs=$((expected_refs + expected))
done

echo "[image-verify] OK: 9 explicit Dockerfile targets map to ${expected_refs} runtime/migration manifest image references"

if grep -RIn --include='Dockerfile' --include='*.yaml' --include='*.yml' --include='*.sh' --include='Jenkinsfile' -E ':latest([[:space:]]|$)' services apps/admin-web deploy scripts/build-images.sh Jenkinsfile; then
  fail 'mutable :latest reference found in production image/build paths'
fi
echo '[image-verify] OK: no :latest references in production image/build paths'

TEST_SHA='0123456789abcdef0123456789abcdef01234567'
plan="$(./scripts/build-images.sh "$TEST_SHA" --plan)"
grep -q 'PLAN PASS: 9 immutable image targets resolved' <<<"$plan" || fail 'image plan did not resolve all 9 images'

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
./scripts/update-gitops.sh "$TEST_SHA" "$tmp/rendered" >/dev/null
for name in "${ZABISA_IMAGE_NAMES[@]}"; do
  expected="$(zabisa_expected_manifest_refs_for "$name")"
  count="$( (grep -RhF -o "harbor-dt.co.id/zabisa/${name}:${TEST_SHA}" "$tmp/rendered" || true) | wc -l | tr -d ' ')"
  [[ "$count" == "$expected" ]] || fail "rendered image count mismatch for $name: expected $expected got $count"
done
if grep -Rqs 'REPLACE_SHA' "$tmp/rendered"; then fail 'REPLACE_SHA remains in rendered manifests'; fi

echo "[image-verify] OK: GitOps render replaces all ${expected_refs} runtime + migration placeholders with immutable SHA tags"

grep -q 'name: allow-admin-egress-to-api-gateway' deploy/kubernetes/base/platform.yaml || fail 'admin -> api-gateway egress policy missing'
grep -q 'name: allow-admin-ingress-to-api-gateway' deploy/kubernetes/base/platform.yaml || fail 'api-gateway ingress from admin policy missing'
grep -q 'name: allow-ingress-to-admin-web' deploy/kubernetes/base/platform.yaml || fail 'admin ingress policy missing'
echo '[image-verify] OK: admin-web NetworkPolicy edges are explicit'

echo '[image-verify] PASS: immutable image pipeline baseline is internally consistent.'
