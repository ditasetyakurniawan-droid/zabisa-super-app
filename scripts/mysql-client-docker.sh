#!/usr/bin/env bash
set -Eeuo pipefail
set +x

# Oracle MySQL client runner for Linux operator workstations whose system
# `mysql` command is provided by MariaDB and therefore lacks --ssl-mode.
readonly DEFAULT_IMAGE='mysql@sha256:b3b90af2a6552ae30c266fdb7d5dd55f3afb72404bb78d37fe8a23eb857fd3fb'
client_image="${MYSQL_CLIENT_IMAGE:-$DEFAULT_IMAGE}"
defaults_file=''

for argument in "$@"; do
  case "$argument" in
    --defaults-extra-file=*) defaults_file="${argument#--defaults-extra-file=}" ;;
  esac
done

command -v docker >/dev/null 2>&1 || {
  echo '[mysql-client-docker] ERROR: docker is required' >&2
  exit 1
}

docker image inspect "$client_image" >/dev/null 2>&1 || {
  printf '[mysql-client-docker] ERROR: pinned image is not local: %s\n' "$client_image" >&2
  printf '[mysql-client-docker] Pull it explicitly after reviewing the digest.\n' >&2
  exit 1
}

docker_arguments=(
  run
  --rm
  --interactive
  --pull=never
  --network=host
  --user "$(id -u):$(id -g)"
  --env HOME=/tmp
)

declare -A mounted_directories=()
add_readonly_mount() {
  local directory="$1"
  [[ -d "$directory" ]] || {
    printf '[mysql-client-docker] ERROR: mount directory is missing: %s\n' "$directory" >&2
    exit 1
  }
  if [[ -z "${mounted_directories[$directory]+present}" ]]; then
    docker_arguments+=(--volume "$directory:$directory:ro")
    mounted_directories["$directory"]=present
  fi
}

if [[ -n "$defaults_file" ]]; then
  [[ -r "$defaults_file" ]] || {
    printf '[mysql-client-docker] ERROR: defaults file is unreadable: %s\n' "$defaults_file" >&2
    exit 1
  }

  add_readonly_mount "$(dirname "$defaults_file")"

  ssl_ca="$(
    awk -F= '
      $1 == "ssl-ca" {
        sub(/^[^=]*=/, "")
        gsub(/^"|"$/, "")
        print
        exit
      }
    ' "$defaults_file"
  )"
  [[ -n "$ssl_ca" && -r "$ssl_ca" ]] || {
    echo '[mysql-client-docker] ERROR: readable ssl-ca is required in the defaults file' >&2
    exit 1
  }
  add_readonly_mount "$(dirname "$ssl_ca")"
fi

exec docker "${docker_arguments[@]}" \
  --entrypoint mysql \
  "$client_image" \
  "$@"
