#!/usr/bin/env bash
set -euo pipefail
umask 077

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
# shellcheck source=scripts/image-inventory.sh
source scripts/image-inventory.sh

usage() {
  cat <<'USAGE'
Usage: ./scripts/build-images.sh <full-git-sha> [mode]

Modes:
  --plan             Print the immutable plan; no Docker/registry access.
  --build-only       Build all images; do not scan or push.
  --build-scan       Build, scan and emit scan/SBOM attestations (default).
  --push-only        Verify prior attestations, push, then prove Harbor digests.
  --build-scan-push  Build and scan every image before any image is pushed.
  --cleanup-local    Remove only the nine exact Zabisa images for this Git SHA.

Environment:
  HARBOR=harbor-dt.co.id
  PROJECT=zabisa
  PULL_BASE_IMAGES=1
  TRIVY_BIN=trivy
  TRIVY_SEVERITY=CRITICAL,HIGH
  SBOM_DIR=build/sbom
  IMAGE_EVIDENCE_DIR=build/image-evidence
  DOCKER_PLATFORM=linux/amd64

Non-plan modes require a clean worktree and an exact full HEAD SHA. Base images
are digest-pinned in Dockerfiles. Registry authentication and CA trust remain
external; this script never performs docker login or weakens TLS verification.
USAGE
}

SHA="${1:-}"
MODE="${2:---build-scan}"
if [[ ! "$SHA" =~ ^[0-9a-fA-F]{40}$ ]]; then
  echo "ERROR: immutable image tag must be the full 40-character Git commit SHA." >&2
  exit 64
fi
SHA="${SHA,,}"

case "$MODE" in
  --plan|--build-only|--build-scan|--push-only|--build-scan-push|--cleanup-local) ;;
  *) echo "ERROR: unsupported mode: $MODE" >&2; usage >&2; exit 64 ;;
esac

HARBOR="${HARBOR:-harbor-dt.co.id}"
PROJECT="${PROJECT:-zabisa}"
PULL_BASE_IMAGES="${PULL_BASE_IMAGES:-1}"
TRIVY_BIN="${TRIVY_BIN:-trivy}"
TRIVY_SEVERITY="${TRIVY_SEVERITY:-CRITICAL,HIGH}"
SBOM_DIR="${SBOM_DIR:-build/sbom}"
IMAGE_EVIDENCE_DIR="${IMAGE_EVIDENCE_DIR:-build/image-evidence}"
DOCKER_PLATFORM="${DOCKER_PLATFORM:-linux/amd64}"

HARBOR="${HARBOR%/}"
PROJECT="${PROJECT#/}"
PROJECT="${PROJECT%/}"

if [[ -z "$HARBOR" || "$HARBOR" == *://* || "$HARBOR" =~ [[:space:]] ]]; then
  echo "ERROR: HARBOR must be a registry host[:port] without scheme/whitespace." >&2
  exit 64
fi
if [[ -z "$PROJECT" || "$PROJECT" =~ [[:space:]] || "$PROJECT" == *:* ]]; then
  echo "ERROR: PROJECT must be a registry project/path without whitespace/tag." >&2
  exit 64
fi
if [[ "$PULL_BASE_IMAGES" != "0" && "$PULL_BASE_IMAGES" != "1" ]]; then
  echo "ERROR: PULL_BASE_IMAGES must be 0 or 1." >&2
  exit 64
fi
if [[ "$DOCKER_PLATFORM" != "linux/amd64" ]]; then
  echo "ERROR: DT4 verified cluster platform is linux/amd64; got $DOCKER_PLATFORM." >&2
  exit 64
fi
if [[ "$TRIVY_BIN" == *[[:space:]]* ]]; then
  echo "ERROR: TRIVY_BIN must be one executable path without arguments." >&2
  exit 64
fi

image_ref() {
  printf '%s/%s/%s:%s\n' "$HARBOR" "$PROJECT" "$1" "$SHA"
}

attestation_file() {
  printf '%s/scans/%s-%s.attestation.tsv\n' "$IMAGE_EVIDENCE_DIR" "$1" "$SHA"
}

scan_json_file() {
  printf '%s/scans/%s-%s.trivy.json\n' "$IMAGE_EVIDENCE_DIR" "$1" "$SHA"
}

sbom_file() {
  printf '%s/%s-%s.cdx.json\n' "$SBOM_DIR" "$1" "$SHA"
}

image_id_for() {
  docker image inspect --format '{{.Id}}' "$1"
}

image_revision_for() {
  docker image inspect --format '{{index .Config.Labels "org.opencontainers.image.revision"}}' "$1"
}

printf '[images] immutable tag: %s\n' "$SHA"
printf '[images] registry: %s/%s\n' "$HARBOR" "$PROJECT"
printf '[images] platform: %s\n' "$DOCKER_PLATFORM"

for name in "${ZABISA_IMAGE_NAMES[@]}"; do
  dockerfile="$(zabisa_dockerfile_for "$name")"
  [[ -f "$dockerfile" ]] || {
    echo "ERROR: Dockerfile missing for $name: $dockerfile" >&2
    exit 1
  }
  printf '[images] %-14s %s  (%s)\n' "$name" "$(image_ref "$name")" "$dockerfile"
done

if [[ "$MODE" == "--plan" ]]; then
  echo '[images] PLAN PASS: 9 linux/amd64 immutable targets resolved; no registry access performed.'
  exit 0
fi

if [[ "$MODE" == "--cleanup-local" ]]; then
  command -v docker >/dev/null 2>&1 || { echo 'ERROR: docker is required.' >&2; exit 127; }
  for name in "${ZABISA_IMAGE_NAMES[@]}"; do
    image="$(image_ref "$name")"
    if docker image inspect "$image" >/dev/null 2>&1; then
      docker image rm "$image" >/dev/null || {
        echo "[images] WARNING: local image remains in use: $image" >&2
      }
    fi
  done
  echo "[images] PASS: exact local Zabisa images cleaned for $SHA."
  exit 0
fi

command -v git >/dev/null 2>&1 || { echo 'ERROR: git is required.' >&2; exit 127; }
command -v docker >/dev/null 2>&1 || { echo 'ERROR: docker is required.' >&2; exit 127; }
command -v sha256sum >/dev/null 2>&1 || { echo 'ERROR: sha256sum is required.' >&2; exit 127; }

[[ "$(git rev-parse HEAD)" == "$SHA" ]] || {
  echo "ERROR: requested image SHA does not equal repository HEAD." >&2
  exit 65
}
[[ -z "$(git status --porcelain=v1)" ]] || {
  echo "ERROR: refusing to build/push from a dirty worktree." >&2
  git status --short >&2
  exit 65
}
docker info >/dev/null

need_build=0
need_scan=0
need_push=0
case "$MODE" in
  --build-only) need_build=1 ;;
  --build-scan) need_build=1; need_scan=1 ;;
  --push-only) need_push=1 ;;
  --build-scan-push) need_build=1; need_scan=1; need_push=1 ;;
esac

if (( need_scan )); then
  command -v "$TRIVY_BIN" >/dev/null 2>&1 || {
    echo "ERROR: Trivy executable is required: $TRIVY_BIN" >&2
    exit 127
  }
  mkdir -p "$SBOM_DIR" "$IMAGE_EVIDENCE_DIR/scans"
fi

if (( need_push )); then
  mkdir -p "$IMAGE_EVIDENCE_DIR"
fi

build_args=(--platform "$DOCKER_PLATFORM")
if [[ "$PULL_BASE_IMAGES" == "1" ]]; then
  build_args+=(--pull)
fi

if (( need_build )); then
  for name in "${ZABISA_IMAGE_NAMES[@]}"; do
    dockerfile="$(zabisa_dockerfile_for "$name")"
    image="$(image_ref "$name")"
    echo "[images] BUILD $image"
    docker build "${build_args[@]}" \
      --label "org.opencontainers.image.revision=$SHA" \
      --label "org.opencontainers.image.title=zabisa-$name" \
      -f "$dockerfile" -t "$image" .

    revision="$(image_revision_for "$image")"
    [[ "$revision" == "$SHA" ]] || {
      echo "ERROR: built image revision label mismatch for $name." >&2
      exit 1
    }
  done
fi

if (( need_scan )); then
  trivy_version="$($TRIVY_BIN --version | head -1 | tr '\t' ' ')"
  for name in "${ZABISA_IMAGE_NAMES[@]}"; do
    image="$(image_ref "$name")"
    image_id="$(image_id_for "$image")"
    revision="$(image_revision_for "$image")"
    scan_json="$(scan_json_file "$name")"
    sbom="$(sbom_file "$name")"
    attestation="$(attestation_file "$name")"
    attestation_tmp="${attestation}.tmp"

    [[ "$revision" == "$SHA" ]] || {
      echo "ERROR: image revision label mismatch before scan for $name." >&2
      exit 1
    }

    echo "[images] SCAN  $image"
    "$TRIVY_BIN" image \
      --exit-code 1 \
      --severity "$TRIVY_SEVERITY" \
      --format json \
      --output "$scan_json" \
      "$image"

    echo "[images] SBOM  $image"
    "$TRIVY_BIN" image \
      --format cyclonedx \
      --output "$sbom" \
      "$image"

    scan_sha="$(sha256sum "$scan_json" | awk '{print $1}')"
    sbom_sha="$(sha256sum "$sbom" | awk '{print $1}')"
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
      "$image" "$image_id" "$revision" "$scan_sha" "$sbom_sha" "$trivy_version" \
      >"$attestation_tmp"
    mv "$attestation_tmp" "$attestation"
    echo "[images] ATTEST $attestation"
  done
fi

verify_all_scan_attestations() {
  for name in "${ZABISA_IMAGE_NAMES[@]}"; do
    image="$(image_ref "$name")"
    scan_json="$(scan_json_file "$name")"
    sbom="$(sbom_file "$name")"
    attestation="$(attestation_file "$name")"

    [[ -s "$scan_json" && -s "$sbom" && -s "$attestation" ]] || {
      echo "ERROR: scan/SBOM attestation is incomplete for $name." >&2
      return 1
    }

    IFS=$'\t' read -r att_image att_id att_revision att_scan_sha att_sbom_sha att_trivy <"$attestation"
    [[ "$att_image" == "$image" ]] || { echo "ERROR: attested image mismatch for $name." >&2; return 1; }
    [[ "$att_id" == "$(image_id_for "$image")" ]] || { echo "ERROR: image ID changed after scan for $name." >&2; return 1; }
    [[ "$att_revision" == "$SHA" ]] || { echo "ERROR: attested revision mismatch for $name." >&2; return 1; }
    [[ "$att_scan_sha" == "$(sha256sum "$scan_json" | awk '{print $1}')" ]] || { echo "ERROR: scan evidence changed for $name." >&2; return 1; }
    [[ "$att_sbom_sha" == "$(sha256sum "$sbom" | awk '{print $1}')" ]] || { echo "ERROR: SBOM evidence changed for $name." >&2; return 1; }
    [[ -n "$att_trivy" ]] || { echo "ERROR: Trivy version missing for $name." >&2; return 1; }
  done
}

if (( need_push )); then
  echo '[images] VERIFY all scan attestations before first push'
  verify_all_scan_attestations

  digest_report="$IMAGE_EVIDENCE_DIR/harbor-digests-${SHA}.tsv"
  digest_report_tmp="${digest_report}.tmp"
  printf 'name\timage\tdigest_ref\tlocal_image_id\trevision\tscan_sha256\tsbom_sha256\tpushed_at_utc\n' >"$digest_report_tmp"

  for name in "${ZABISA_IMAGE_NAMES[@]}"; do
    image="$(image_ref "$name")"
    repository="${image%:*}"
    scan_json="$(scan_json_file "$name")"
    sbom="$(sbom_file "$name")"

    push_log="$IMAGE_EVIDENCE_DIR/push-${name}-${SHA}.log"
    push_log_tmp="${push_log}.tmp"

    echo "[images] PUSH  $image"
    docker push "$image" | tee "$push_log_tmp"
    mv "$push_log_tmp" "$push_log"

    remote_digest="$(
      awk '$1 == "digest:" {print $2; exit}' "$push_log"
    )"
    [[ "$remote_digest" =~ ^sha256:[0-9a-f]{64}$ ]] || {
      echo "ERROR: invalid remote Harbor digest for $name: $remote_digest" >&2
      exit 1
    }

    digest_ref="${repository}@${remote_digest}"
    docker image inspect --format '{{range .RepoDigests}}{{println .}}{{end}}' "$image" |
      grep -Fxq "$digest_ref" || {
        echo "ERROR: local/remote digest proof mismatch for $name." >&2
        exit 1
      }

    image_id="$(image_id_for "$image")"
    revision="$(image_revision_for "$image")"
    scan_sha="$(sha256sum "$scan_json" | awk '{print $1}')"
    sbom_sha="$(sha256sum "$sbom" | awk '{print $1}')"
    pushed_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
      "$name" "$image" "$digest_ref" "$image_id" "$revision" \
      "$scan_sha" "$sbom_sha" "$pushed_at" >>"$digest_report_tmp"
    echo "[images] DIGEST $digest_ref"
  done

  mv "$digest_report_tmp" "$digest_report"
  echo "[images] EVIDENCE $digest_report"
  sha256sum "$digest_report"
fi

echo "[images] PASS: mode $MODE completed for ${#ZABISA_IMAGE_NAMES[@]} immutable images."
