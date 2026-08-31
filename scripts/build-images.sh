#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
# shellcheck source=scripts/image-inventory.sh
source scripts/image-inventory.sh

usage() {
  cat <<'USAGE'
Usage: ./scripts/build-images.sh <git-sha> [mode]

Modes:
  --plan             Print immutable image plan only; requires no Docker/registry access.
  --build-only       Build all images; do not scan or push.
  --build-scan       Build, vulnerability-scan and emit CycloneDX SBOMs (default).
  --push-only        Push already-built immutable images; performs no build or scan.
  --build-scan-push  Build, scan/SBOM and push in one invocation.

Environment:
  HARBOR=harbor-dt.co.id
  PROJECT=zabisa
  PULL_BASE_IMAGES=1       Set 0 to avoid docker build --pull.
  TRIVY_SEVERITY=CRITICAL,HIGH
  SBOM_DIR=build/sbom
  DOCKER_PLATFORM=         Optional, e.g. linux/amd64. Empty uses the builder default.

The tag must be a hexadecimal Git object ID (12-64 chars). The script never creates :latest.
Registry authentication is intentionally external; Jenkins logs in with credentials before push.
USAGE
}

SHA="${1:-}"
MODE="${2:---build-scan}"
if [[ -z "$SHA" ]]; then usage >&2; exit 64; fi
if [[ ! "$SHA" =~ ^[0-9a-fA-F]{12,64}$ ]]; then
  echo "ERROR: immutable image tag must be a 12-64 character hexadecimal Git SHA; got: $SHA" >&2
  exit 64
fi
SHA="${SHA,,}"

case "$MODE" in
  --plan|--build-only|--build-scan|--push-only|--build-scan-push) ;;
  *) echo "ERROR: unsupported mode: $MODE" >&2; usage >&2; exit 64 ;;
esac

HARBOR="${HARBOR:-harbor-dt.co.id}"
PROJECT="${PROJECT:-zabisa}"
PULL_BASE_IMAGES="${PULL_BASE_IMAGES:-1}"
TRIVY_SEVERITY="${TRIVY_SEVERITY:-CRITICAL,HIGH}"
SBOM_DIR="${SBOM_DIR:-build/sbom}"
DOCKER_PLATFORM="${DOCKER_PLATFORM:-}"

HARBOR="${HARBOR%/}"
PROJECT="${PROJECT#/}"; PROJECT="${PROJECT%/}"
if [[ -z "$HARBOR" || "$HARBOR" == *://* || "$HARBOR" =~ [[:space:]] ]]; then
  echo "ERROR: HARBOR must be a registry host[:port] without URL scheme or whitespace." >&2
  exit 64
fi
if [[ -z "$PROJECT" || "$PROJECT" =~ [[:space:]] || "$PROJECT" == *:* ]]; then
  echo "ERROR: PROJECT must be a non-empty registry project/path without whitespace or tag separator." >&2
  exit 64
fi

image_ref() { printf '%s/%s/%s:%s\n' "$HARBOR" "$PROJECT" "$1" "$SHA"; }

printf '[images] immutable tag: %s\n' "$SHA"
printf '[images] registry: %s/%s\n' "$HARBOR" "$PROJECT"
for name in "${ZABISA_IMAGE_NAMES[@]}"; do
  dockerfile="$(zabisa_dockerfile_for "$name")"
  [[ -f "$dockerfile" ]] || { echo "ERROR: Dockerfile missing for $name: $dockerfile" >&2; exit 1; }
  printf '[images] %-14s %s  (%s)\n' "$name" "$(image_ref "$name")" "$dockerfile"
done

if [[ "$MODE" == "--plan" ]]; then
  echo '[images] PLAN PASS: 9 immutable image targets resolved; no registry access performed.'
  exit 0
fi

command -v docker >/dev/null 2>&1 || { echo 'ERROR: docker is required for this mode.' >&2; exit 127; }

need_scan=0
need_build=0
need_push=0
case "$MODE" in
  --build-only) need_build=1 ;;
  --build-scan) need_build=1; need_scan=1 ;;
  --push-only) need_push=1 ;;
  --build-scan-push) need_build=1; need_scan=1; need_push=1 ;;
esac

if (( need_scan )); then
  command -v trivy >/dev/null 2>&1 || { echo 'ERROR: trivy is required for image scanning/SBOM generation.' >&2; exit 127; }
  mkdir -p "$SBOM_DIR"
fi

build_args=()
if [[ "$PULL_BASE_IMAGES" == "1" ]]; then build_args+=(--pull); fi
if [[ -n "$DOCKER_PLATFORM" ]]; then build_args+=(--platform "$DOCKER_PLATFORM"); fi

for name in "${ZABISA_IMAGE_NAMES[@]}"; do
  dockerfile="$(zabisa_dockerfile_for "$name")"
  image="$(image_ref "$name")"

  if (( need_build )); then
    echo "[images] BUILD $image"
    docker build "${build_args[@]}" \
      --label "org.opencontainers.image.revision=$SHA" \
      --label "org.opencontainers.image.title=zabisa-$name" \
      -f "$dockerfile" -t "$image" .
  fi

  if (( need_scan )); then
    echo "[images] SCAN  $image"
    trivy image --exit-code 1 --severity "$TRIVY_SEVERITY" "$image"
    echo "[images] SBOM  $image"
    trivy image --format cyclonedx --output "$SBOM_DIR/${name}-${SHA}.cdx.json" "$image"
  fi

  if (( need_push )); then
    echo "[images] PUSH  $image"
    docker image inspect "$image" >/dev/null
    docker push "$image"
  fi
done

echo "[images] PASS: mode $MODE completed for ${#ZABISA_IMAGE_NAMES[@]} immutable images."
