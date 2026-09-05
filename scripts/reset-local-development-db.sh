#!/usr/bin/env bash

set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

confirm="${ZABISA_LOCAL_RESET_CONFIRM:-}"
if [[ "${1:-}" != "--run" || "$confirm" != "RESET-ZABISA-LOCAL-DEMO-DB" ]]; then
  cat <<'USAGE'
This command backs up and reinitializes only the local Zabisa Docker MySQL
volume. It never connects to DT or Kubernetes.

Run explicitly:
  ZABISA_LOCAL_RESET_CONFIRM=RESET-ZABISA-LOCAL-DEMO-DB \
    ./scripts/reset-local-development-db.sh --run
USAGE
  exit 2
fi

for command_name in docker curl; do
  command -v "$command_name" >/dev/null 2>&1 || {
    echo "ERROR: required command is unavailable: $command_name" >&2
    exit 10
  }
done

docker compose config --quiet

mysql_container="$(docker compose ps -q mysql)"
[[ -n "$mysql_container" ]] || {
  echo 'ERROR: local Zabisa MySQL container is not running.' >&2
  exit 11
}

mysql_volume="$(
  docker inspect "$mysql_container" \
    --format '{{range .Mounts}}{{if eq .Destination "/var/lib/mysql"}}{{.Name}}{{end}}{{end}}'
)"
[[ -n "$mysql_volume" ]] || {
  echo 'ERROR: could not resolve the exact /var/lib/mysql volume.' >&2
  exit 12
}

compose_volume_label="$(
  docker volume inspect "$mysql_volume" \
    --format '{{index .Labels "com.docker.compose.volume"}}'
)"
[[ "$compose_volume_label" == 'mysql_data' ]] || {
  echo "ERROR: refusing unexpected volume: $mysql_volume" >&2
  exit 13
}

backup_root="${ZABISA_LOCAL_BACKUP_DIR:-$HOME/project-homelab/zabisa-local-db-backups}"
timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
backup_dir="$backup_root/$timestamp"
mkdir -p "$backup_dir"
chmod 700 "$backup_root" "$backup_dir"
dump="$backup_dir/all-databases.sql"

echo "[local-db] Backing up $mysql_volume to $dump"
docker compose exec -T mysql sh -lc '
  MYSQL_PWD="$MYSQL_ROOT_PASSWORD" exec mysqldump \
    --host=127.0.0.1 \
    --user=root \
    --all-databases \
    --single-transaction \
    --routines \
    --events \
    --hex-blob
' >"$dump"
chmod 600 "$dump"
[[ -s "$dump" ]] || {
  echo 'ERROR: local database backup is empty; volume was not changed.' >&2
  exit 14
}
sha256sum "$dump" >"$dump.sha256"

echo '[local-db] Stopping only the Zabisa Compose project.'
docker compose down --remove-orphans

resolved_label="$(
  docker volume inspect "$mysql_volume" \
    --format '{{index .Labels "com.docker.compose.volume"}}'
)"
[[ "$resolved_label" == 'mysql_data' ]] || {
  echo 'ERROR: volume label changed after stop; refusing removal.' >&2
  exit 15
}

docker volume rm "$mysql_volume"

echo '[local-db] Rebuilding the Zabisa local stack with a fresh schema.'
docker compose up -d --build

ready='false'
for attempt in $(seq 1 90); do
  if curl -fsS http://127.0.0.1:8088/health/ready >/dev/null 2>&1 &&
     curl -fsS http://127.0.0.1:3001/login >/dev/null 2>&1; then
    ready='true'
    break
  fi
  echo "[local-db] Waiting for API and Backoffice: $attempt/90"
  sleep 3
done

[[ "$ready" == 'true' ]] || {
  docker compose ps
  docker compose logs --tail=160 --no-color identity content student tahfidz academic donation notification api-gateway admin-web
  echo "ERROR: local stack did not become ready. Backup: $dump" >&2
  exit 16
}

./scripts/verify-phase2.sh
docker compose ps

echo '[local-db] PASS: local Zabisa API and Backoffice are ready.'
echo "[local-db] Backup: $dump"
echo '[local-db] DT migration and ArgoCD sync were not touched.'
