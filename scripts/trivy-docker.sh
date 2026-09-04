#!/usr/bin/env bash

set -Eeuo pipefail
set +x
umask 077

TRIVY_IMAGE='aquasec/trivy:0.74.0@sha256:62b1e65e8869bc4b4c6aa4fa2b21595256c7c2f6018a9d9ad61caf87187c1969'

command -v docker >/dev/null 2>&1 || {
  echo '[trivy-docker] ERROR: Docker CLI is required.' >&2
  exit 127
}

docker info >/dev/null

workspace="$(pwd -P)"
cache_dir="${TRIVY_CACHE_DIR:-$workspace/build/trivy-cache}"
mkdir -p "$cache_dir"

docker_socket='/var/run/docker.sock'
[[ -S "$docker_socket" ]] || {
  echo "[trivy-docker] ERROR: Docker socket is missing: $docker_socket" >&2
  exit 1
}

socket_gid="$(stat -c '%g' "$docker_socket")"
run_args=(
  --rm
  --user "$(id -u):$(id -g)"
  --group-add "$socket_gid"
  --cap-drop ALL
  --security-opt no-new-privileges=true
  --tmpfs /tmp:rw,noexec,nosuid,nodev
  -e DOCKER_HOST="unix://$docker_socket"
)

# Jenkins runs inside the existing Compose container while talking to the host
# Docker daemon. Reuse that container's bind mounts so the scanner sees the
# exact same workspace path and writes evidence back with the Jenkins UID/GID.
if [[ -n "${HOSTNAME:-}" ]] &&
   docker inspect "$HOSTNAME" >/dev/null 2>&1; then
  run_args+=(
    --volumes-from "$HOSTNAME"
    -w "$workspace"
  )
else
  run_args+=(
    -v "$docker_socket:$docker_socket"
    -v "$workspace:$workspace"
    -w "$workspace"
  )
fi

echo "[trivy-docker] image=$TRIVY_IMAGE" >&2

exec docker run "${run_args[@]}" \
  "$TRIVY_IMAGE" \
  --cache-dir "$cache_dir" \
  --disable-telemetry \
  "$@"
