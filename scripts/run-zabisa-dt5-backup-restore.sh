#!/usr/bin/env bash
set -Eeuo pipefail
set +x
umask 077

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

readonly MYSQL_IMAGE_DEFAULT='mysql@sha256:b3b90af2a6552ae30c266fdb7d5dd55f3afb72404bb78d37fe8a23eb857fd3fb'
readonly DATABASES=(identity_db content_db student_db tahfidz_db academic_db donation_db notification_db)

fail() { printf '[dt5-backup] ERROR: %s\n' "$*" >&2; exit 1; }
log() { printf '[dt5-backup] %s\n' "$*"; }
need() { command -v "$1" >/dev/null 2>&1 || fail "$1 is required"; }

[[ "${1:-}" == '--run' ]] || fail 'usage: run-zabisa-dt5-backup-restore.sh --run'
[[ "${DT5_CONFIRM:-}" == 'RUN-DT5-BACKUP-RESTORE' ]] ||
  fail 'set DT5_CONFIRM=RUN-DT5-BACKUP-RESTORE for the exact recovery-proof target'

operator_env="${ZABISA_OPERATOR_ENV:-$HOME/.config/zabisa/operator.env}"
[[ -r "$operator_env" ]] || fail "operator environment is unreadable: $operator_env"
# shellcheck disable=SC1090
source "$operator_env"

: "${MYSQL_ADMIN_HOST:?MYSQL_ADMIN_HOST is required}"
: "${MYSQL_ADMIN_PORT:?MYSQL_ADMIN_PORT is required}"
: "${MYSQL_ADMIN_USER:?MYSQL_ADMIN_USER is required}"
: "${MYSQL_ADMIN_PASSWORD_FILE:?MYSQL_ADMIN_PASSWORD_FILE is required}"
: "${MYSQL_SSL_CA:?MYSQL_SSL_CA is required}"

for command_name in docker openssl sha256sum python3 mktemp stat date cmp; do
  need "$command_name"
done

[[ -r "$MYSQL_ADMIN_PASSWORD_FILE" ]] || fail 'MySQL admin password file is unreadable'
[[ -r "$MYSQL_SSL_CA" ]] || fail 'MySQL CA is unreadable'
for protected in "$operator_env" "$MYSQL_ADMIN_PASSWORD_FILE"; do
  mode="$(stat -c '%a' "$protected")"
  (( (8#$mode & 077) == 0 )) || fail "$protected must not be group/world accessible (mode=$mode)"
done

mysql_image="${MYSQL_CLIENT_IMAGE:-$MYSQL_IMAGE_DEFAULT}"
docker image inspect "$mysql_image" >/dev/null 2>&1 ||
  fail "reviewed MySQL image is not local: $mysql_image"

backup_root="${ZABISA_BACKUP_DIR:-$HOME/project-homelab/zabisa-dt5-backups}"
mkdir -p "$backup_root"
chmod 700 "$backup_root"

passphrase_file="${ZABISA_BACKUP_PASSPHRASE_FILE:-$HOME/.config/zabisa/dt-backup-passphrase}"
if [[ ! -e "$passphrase_file" ]]; then
  mkdir -p "$(dirname "$passphrase_file")"
  openssl rand -base64 48 > "$passphrase_file"
  chmod 600 "$passphrase_file"
  log "created backup passphrase file: $passphrase_file"
  log 'copy this file to an approved independent secret store before migration approval'
fi
[[ -r "$passphrase_file" ]] || fail 'backup passphrase file is unreadable'
passphrase_mode="$(stat -c '%a' "$passphrase_file")"
(( (8#$passphrase_mode & 077) == 0 )) || fail "backup passphrase file mode must be 0600/0400 (mode=$passphrase_mode)"

stamp="$(date -u +%Y%m%dT%H%M%SZ)"
evidence_dir="$backup_root/$stamp"
mkdir -p "$evidence_dir"
chmod 700 "$evidence_dir"
archive="$evidence_dir/zabisa-seven-schemas-${stamp}.sql.enc"
metadata="$evidence_dir/backup-restore-evidence.env"
source_inventory="$evidence_dir/source-inventory.tsv"
restore_inventory="$evidence_dir/restore-inventory.tsv"

temp_dir="$(mktemp -d "${TMPDIR:-/tmp}/zabisa-dt5.XXXXXX")"
source_cnf="$temp_dir/source.cnf"
restore_cnf="$temp_dir/restore.cnf"
restore_password_file="$temp_dir/restore-root-password"
restore_container="zabisa-dt5-restore-${stamp,,}"
restore_container="${restore_container//:/-}"

cleanup() {
  rc=$?
  set +e
  if docker container inspect "$restore_container" >/dev/null 2>&1; then
    docker rm -fv "$restore_container" >/dev/null 2>&1
  fi
  rm -rf -- "$temp_dir"
  exit "$rc"
}
trap cleanup EXIT INT TERM

escape_cnf() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  printf '"%s"' "$value"
}

admin_password="$(<"$MYSQL_ADMIN_PASSWORD_FILE")"
[[ -n "$admin_password" && "$admin_password" != *$'\n'* && "$admin_password" != *$'\r'* ]] ||
  fail 'MySQL admin password must be one non-empty line'
{
  printf '[client]\nprotocol=TCP\n'
  printf 'host=%s\n' "$(escape_cnf "$MYSQL_ADMIN_HOST")"
  printf 'port=%s\n' "$MYSQL_ADMIN_PORT"
  printf 'user=%s\n' "$(escape_cnf "$MYSQL_ADMIN_USER")"
  printf 'password=%s\n' "$(escape_cnf "$admin_password")"
  printf 'ssl-mode=VERIFY_CA\nssl-ca=%s\n' "$(escape_cnf "$MYSQL_SSL_CA")"
} > "$source_cnf"
chmod 600 "$source_cnf"
unset admin_password

docker_mysql() {
  local entrypoint="$1"
  shift
  docker run --rm --interactive --pull=never --network=host \
    --user "$(id -u):$(id -g)" --env HOME=/tmp \
    --volume "$temp_dir:$temp_dir:ro" \
    --volume "$(dirname "$MYSQL_SSL_CA"):$(dirname "$MYSQL_SSL_CA"):ro" \
    --entrypoint "$entrypoint" "$mysql_image" "$@"
}

source_query() {
  docker_mysql mysql --defaults-extra-file="$source_cnf" --batch --skip-column-names "$@"
}

inventory_source() {
  printf 'database\ttables\tmigration_rows\n' > "$source_inventory"
  local database table_count migration_rows
  for database in "${DATABASES[@]}"; do
    table_count="$(source_query -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='$database';")"
    migration_rows=0
    if [[ "$(source_query -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='$database' AND table_name='schema_migrations';")" == 1 ]]; then
      migration_rows="$(source_query "$database" -e 'SELECT COUNT(*) FROM schema_migrations;')"
    fi
    printf '%s\t%s\t%s\n' "$database" "$table_count" "$migration_rows" >> "$source_inventory"
  done
}

log 'verifying source TLS and recovery coordinates'
server_version="$(source_query -e 'SELECT VERSION();')"
ssl_cipher="$(source_query -e "SHOW SESSION STATUS LIKE 'Ssl_cipher';" | awk 'NR==1 {print $2}')"
[[ -n "$ssl_cipher" ]] || fail 'source MySQL session is not encrypted'
log_bin="$(source_query -e 'SELECT @@GLOBAL.log_bin;')"
[[ "$log_bin" == 1 ]] || fail 'MySQL binary logging is disabled; recovery position cannot be proven'
binlog_status="$(source_query -e 'SHOW BINARY LOG STATUS;' 2>/dev/null || source_query -e 'SHOW MASTER STATUS;')"
[[ -n "$binlog_status" ]] || fail 'MySQL binary log file/position is unavailable'
binlog_file="$(awk 'NR==1 {print $1}' <<<"$binlog_status")"
binlog_position="$(awk 'NR==1 {print $2}' <<<"$binlog_status")"
[[ "$binlog_position" =~ ^[0-9]+$ ]] || fail 'invalid binlog position'

inventory_source
backup_started="$(date -u +%FT%TZ)"
backup_epoch="$(date +%s)"
log 'creating encrypted consistent backup for seven Zabisa schemas'
docker_mysql mysqldump --defaults-extra-file="$source_cnf" \
  --single-transaction --source-data=2 --routines --events --triggers \
  --hex-blob --set-gtid-purged=OFF --databases "${DATABASES[@]}" |
  openssl enc -aes-256-cbc -salt -pbkdf2 -iter 200000 \
    -pass file:"$passphrase_file" -out "$archive"
[[ -s "$archive" ]] || fail 'encrypted backup archive is empty'
backup_ended="$(date -u +%FT%TZ)"
backup_seconds="$(( $(date +%s) - backup_epoch ))"
archive_sha256="$(sha256sum "$archive" | awk '{print $1}')"
archive_bytes="$(stat -c '%s' "$archive")"

openssl rand -hex 32 > "$restore_password_file"
chmod 600 "$restore_password_file"
restore_password="$(<"$restore_password_file")"
{
  printf '[client]\nprotocol=SOCKET\nuser=root\n'
  printf 'password=%s\n' "$(escape_cnf "$restore_password")"
} > "$restore_cnf"
chmod 600 "$restore_cnf"
unset restore_password

restore_started="$(date -u +%FT%TZ)"
restore_epoch="$(date +%s)"
log 'starting network-isolated restore target'
docker run --detach --pull=never --name "$restore_container" --network none \
  --env MYSQL_ROOT_PASSWORD_FILE=/run/zabisa/restore-root-password \
  --volume "$temp_dir:/run/zabisa:ro" "$mysql_image" >/dev/null

ready=false
for attempt in $(seq 1 120); do
  if docker exec "$restore_container" mysqladmin \
    --defaults-extra-file=/run/zabisa/restore.cnf ping --silent >/dev/null 2>&1; then
    ready=true
    break
  fi
  state="$(docker inspect -f '{{.State.Status}}' "$restore_container" 2>/dev/null || true)"
  [[ "$state" == running ]] || fail "isolated restore container stopped (state=${state:-unknown})"
  sleep 1
done
[[ "$ready" == true ]] || fail 'isolated restore target did not become ready'

log 'decrypting and restoring only into the network-isolated container'
openssl enc -d -aes-256-cbc -pbkdf2 -iter 200000 \
  -pass file:"$passphrase_file" -in "$archive" |
  docker exec -i "$restore_container" mysql \
    --defaults-extra-file=/run/zabisa/restore.cnf

printf 'database\ttables\tmigration_rows\n' > "$restore_inventory"
for database in "${DATABASES[@]}"; do
  table_count="$(docker exec "$restore_container" mysql --defaults-extra-file=/run/zabisa/restore.cnf --batch --skip-column-names -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='$database';")"
  migration_rows=0
  if [[ "$(docker exec "$restore_container" mysql --defaults-extra-file=/run/zabisa/restore.cnf --batch --skip-column-names -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='$database' AND table_name='schema_migrations';")" == 1 ]]; then
    migration_rows="$(docker exec "$restore_container" mysql --defaults-extra-file=/run/zabisa/restore.cnf --batch --skip-column-names "$database" -e 'SELECT COUNT(*) FROM schema_migrations;')"
  fi
  printf '%s\t%s\t%s\n' "$database" "$table_count" "$migration_rows" >> "$restore_inventory"
done
cmp -s "$source_inventory" "$restore_inventory" || {
  diff -u "$source_inventory" "$restore_inventory" >&2 || true
  fail 'isolated restore inventory differs from the source snapshot'
}

restore_ended="$(date -u +%FT%TZ)"
restore_seconds="$(( $(date +%s) - restore_epoch ))"
{
  printf 'status=PASS\n'
  printf 'source_host=%s\n' "$MYSQL_ADMIN_HOST"
  printf 'source_port=%s\n' "$MYSQL_ADMIN_PORT"
  printf 'server_version=%s\n' "$server_version"
  printf 'tls_cipher=%s\n' "$ssl_cipher"
  printf 'databases=7\n'
  printf 'backup_started=%s\nbackup_ended=%s\nbackup_seconds=%s\n' "$backup_started" "$backup_ended" "$backup_seconds"
  printf 'archive=%s\narchive_bytes=%s\narchive_sha256=%s\n' "$archive" "$archive_bytes" "$archive_sha256"
  printf 'binlog_file=%s\nbinlog_position=%s\n' "$binlog_file" "$binlog_position"
  printf 'restore_started=%s\nrestore_ended=%s\nrestore_seconds=%s\n' "$restore_started" "$restore_ended" "$restore_seconds"
  printf 'restore_target=network-isolated-ephemeral-container\nrestore_cleanup=removed-by-exit-trap\n'
  printf 'operator_user=%s\noperator_host=%s\n' "$(id -un)" "$(hostname)"
  printf 'reviewer=%s\n' "${ZABISA_DT5_REVIEWER:-interactive-operator}"
} > "$metadata"
chmod 600 "$archive" "$metadata" "$source_inventory" "$restore_inventory"

log "PASS: encrypted backup and isolated restore verified"
log "evidence: $evidence_dir"
log "archive SHA-256: $archive_sha256"
log "recovery position: $binlog_file:$binlog_position"
