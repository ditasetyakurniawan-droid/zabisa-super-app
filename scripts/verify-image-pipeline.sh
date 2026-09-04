#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
# shellcheck source=scripts/image-inventory.sh
source scripts/image-inventory.sh

fail() { echo "[image-verify] ERROR: $*" >&2; exit 1; }

[[ -x scripts/trivy-docker.sh ]] || fail 'Dockerized Trivy wrapper is missing or not executable'

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
grep -q 'PLAN PASS: 9 linux/amd64 immutable targets resolved' <<<"$plan" || fail 'image plan did not resolve all 9 linux/amd64 images'

go_digest='sha256:28d89ee9cc0ff9fec75c82ca201e6bf7fdf9a679d4b7b24dfa04f2bb766bb468'
distroless_digest='sha256:afa5c872c891853ca7fcf1f12c3edb23f7eeef36189728842dd51042ff57f7ab'
node_digest='sha256:c610fcdfb1d5b4740dd70c284ed3cb16bb857e0f7166196e36a5501df7a3aa32'
trivy_digest='sha256:62b1e65e8869bc4b4c6aa4fa2b21595256c7c2f6018a9d9ad61caf87187c1969'

[[ "$(grep -Rh '^FROM golang:1.26.7-alpine@' services/*/Dockerfile | wc -l | tr -d ' ')" == '8' ]] || fail 'all eight Go builders must be digest-pinned'
[[ "$(grep -RhF "$go_digest" services/*/Dockerfile | wc -l | tr -d ' ')" == '8' ]] || fail 'Go builder digest mismatch'
[[ "$(grep -RhF "$distroless_digest" services/*/Dockerfile | wc -l | tr -d ' ')" == '8' ]] || fail 'distroless runtime digest mismatch'
[[ "$(grep -F "$node_digest" apps/admin-web/Dockerfile | wc -l | tr -d ' ')" == '2' ]] || fail 'admin-web build/runtime digest mismatch'
grep -Fq "aquasec/trivy:0.74.0@$trivy_digest" scripts/trivy-docker.sh || fail 'Trivy image/version digest mismatch'

if awk '$1 == "FROM" && $2 !~ /@sha256:[0-9a-f]{64}$/ {print FILENAME ":" FNR ":" $0}' services/*/Dockerfile apps/admin-web/Dockerfile | grep -q .; then
  fail 'an application base image is not digest-pinned'
fi
echo '[image-verify] OK: all application base images are pinned to reviewed OCI index digests'

grep -Fq -- '--volumes-from "$HOSTNAME"' Jenkinsfile || fail 'Jenkins Docker-outside-Docker workspace contract missing'
grep -Fq 'TRIVY_BIN=./scripts/trivy-docker.sh' Jenkinsfile || fail 'Jenkins does not select the pinned Dockerized Trivy wrapper'
grep -Fq -- '-v "$docker_socket:$docker_socket"' scripts/trivy-docker.sh || fail 'Trivy Docker socket mount missing'
grep -Fq -- '--cap-drop ALL' scripts/trivy-docker.sh || fail 'Trivy capability drop missing'
grep -Fq -- '--security-opt no-new-privileges=true' scripts/trivy-docker.sh || fail 'Trivy no-new-privileges control missing'
if grep -Eq 'aquasec/trivy:(latest|[[:space:]]|$)' scripts/trivy-docker.sh Jenkinsfile; then
  fail 'mutable Trivy image reference found'
fi
echo '[image-verify] OK: Jenkins Compose workspace and digest-pinned Dockerized Trivy contract are explicit'

grep -Fq 'refusing to build/push from a dirty worktree' scripts/build-images.sh || fail 'dirty-worktree build rejection missing'
grep -Fq 'VERIFY all scan attestations before first push' scripts/build-images.sh || fail 'pre-push scan attestation gate missing'
grep -Fq 'docker buildx imagetools inspect' scripts/build-images.sh || fail 'remote digest inspection missing'
grep -Fq 'harbor-digests-${SHA}.tsv' scripts/build-images.sh || fail 'Harbor digest evidence report missing'
grep -Fq 'local/remote digest proof mismatch' scripts/build-images.sh || fail 'local/remote digest comparison missing'

if grep -Ein -- '--insecure|--tls-verify=false|curl[[:space:]].*-k([[:space:]]|$)' scripts/build-images.sh scripts/trivy-docker.sh Jenkinsfile; then
  fail 'insecure registry/TLS bypass found in image pipeline'
fi
echo '[image-verify] OK: scan attestations and verified Harbor digest evidence are required before completion'

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
