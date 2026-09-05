#!/usr/bin/env bash
set -Eeuo pipefail
set +x
umask 077

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

fail() { printf '[dt-admin] ERROR: %s\n' "$*" >&2; exit 1; }
log() { printf '[dt-admin] %s\n' "$*"; }
need() { command -v "$1" >/dev/null 2>&1 || fail "$1 is required"; }

[[ "${1:-}" == '--run' ]] || fail 'usage: bootstrap-zabisa-dt-super-admin.sh --run'
[[ "${DT8_ADMIN_CONFIRM:-}" == 'CREATE-INITIAL-DT-SUPER-ADMIN' ]] ||
  fail 'set DT8_ADMIN_CONFIRM=CREATE-INITIAL-DT-SUPER-ADMIN'

operator_env="${ZABISA_OPERATOR_ENV:-$HOME/.config/zabisa/operator.env}"
[[ -r "$operator_env" ]] || fail "operator environment is unreadable: $operator_env"
# shellcheck disable=SC1090
source "$operator_env"

: "${MYSQL_ADMIN_HOST:?MYSQL_ADMIN_HOST is required}"
: "${MYSQL_ADMIN_PORT:?MYSQL_ADMIN_PORT is required}"
: "${MYSQL_ADMIN_USER:?MYSQL_ADMIN_USER is required}"
: "${MYSQL_ADMIN_PASSWORD_FILE:?MYSQL_ADMIN_PASSWORD_FILE is required}"
: "${MYSQL_SSL_CA:?MYSQL_SSL_CA is required}"

for command_name in go python3 openssl mktemp stat; do need "$command_name"; done
mysql_client="${MYSQL_CLIENT_BIN:-$ROOT/scripts/mysql-client-docker.sh}"
[[ -x "$mysql_client" ]] || fail "MySQL client is not executable: $mysql_client"

credential_dir="${ZABISA_OPERATOR_CREDENTIAL_DIR:-$HOME/.config/zabisa}"
email_file="$credential_dir/dt-admin-email"
password_file="$credential_dir/dt-admin-password"
mkdir -p "$credential_dir"
chmod 700 "$credential_dir"

if [[ -e "$email_file" || -e "$password_file" ]]; then
  fail "operator credential files already exist; inspect before retry: $email_file / $password_file"
fi

[[ -r /dev/tty && -w /dev/tty ]] || fail 'an interactive terminal is required for secure admin input'
printf 'Email SUPER_ADMIN DT: ' >/dev/tty
IFS= read -r admin_email </dev/tty
admin_email="${admin_email,,}"
[[ "$admin_email" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]] || fail 'invalid admin email format'

printf 'Nama tampilan SUPER_ADMIN DT: ' >/dev/tty
IFS= read -r display_name </dev/tty
display_name_pattern='^[[:alnum:]][[:alnum:] ._-]{2,79}$'
[[ "$display_name" =~ $display_name_pattern ]] ||
  fail 'display name must be 3..80 safe characters'

printf 'Password (minimum 14 chars, upper/lower/digit/symbol): ' >/dev/tty
IFS= read -rs admin_password </dev/tty
printf '\nUlangi password: ' >/dev/tty
IFS= read -rs admin_password_repeat </dev/tty
printf '\n' >/dev/tty
[[ "$admin_password" == "$admin_password_repeat" ]] || fail 'password confirmation differs'
(( ${#admin_password} >= 14 )) || fail 'password must contain at least 14 characters'
[[ "$admin_password" =~ [A-Z] && "$admin_password" =~ [a-z] && "$admin_password" =~ [0-9] && "$admin_password" =~ [^A-Za-z0-9] ]] ||
  fail 'password must contain upper, lower, digit and symbol characters'

temp_dir="$(mktemp -d "${TMPDIR:-/tmp}/zabisa-dt-admin.XXXXXX")"
mysql_cnf="$temp_dir/mysql.cnf"
sql_file="$temp_dir/bootstrap.sql"
cleanup() {
  unset admin_password admin_password_repeat password_hash mysql_password
  rm -rf -- "$temp_dir"
}
trap cleanup EXIT INT TERM

escape_cnf() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  printf '"%s"' "$value"
}
mysql_password="$(<"$MYSQL_ADMIN_PASSWORD_FILE")"
{
  printf '[client]\nprotocol=TCP\n'
  printf 'host=%s\n' "$(escape_cnf "$MYSQL_ADMIN_HOST")"
  printf 'port=%s\n' "$MYSQL_ADMIN_PORT"
  printf 'user=%s\n' "$(escape_cnf "$MYSQL_ADMIN_USER")"
  printf 'password=%s\n' "$(escape_cnf "$mysql_password")"
  printf 'ssl-mode=VERIFY_CA\nssl-ca=%s\n' "$(escape_cnf "$MYSQL_SSL_CA")"
} > "$mysql_cnf"
chmod 600 "$mysql_cnf"
unset mysql_password

mysql_admin() {
  "$mysql_client" --defaults-extra-file="$mysql_cnf" --batch --skip-column-names "$@"
}

[[ "$(mysql_admin -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='identity_db' AND table_name='users';")" == 1 ]] ||
  fail 'identity migration is not complete; users table is missing'
[[ "$(mysql_admin -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='identity_db' AND table_name='audit_logs';")" == 1 ]] ||
  fail 'identity migration is not complete; audit_logs table is missing'
existing_admins="$(mysql_admin identity_db -e "SELECT COUNT(*) FROM users WHERE role='SUPER_ADMIN' AND status='ACTIVE';")"
[[ "$existing_admins" == 0 ]] || fail 'an active SUPER_ADMIN already exists; bootstrap is intentionally one-time'

password_hash="$(printf '%s\n' "$admin_password" | go run ./tools/password-hash)"
[[ "$password_hash" == \$argon2id\$* ]] || fail 'password hash generation failed'
unset admin_password_repeat

user_id="$(python3 -c 'import uuid; print(uuid.uuid4())')"
audit_id="$(python3 -c 'import uuid; print(uuid.uuid4())')"
sql_email="${admin_email//\'/\'\'}"
sql_name="${display_name//\'/\'\'}"
sql_hash="${password_hash//\'/\'\'}"

{
  printf 'START TRANSACTION;\n'
  printf "INSERT INTO users(id,email,password_hash,display_name,role,status) VALUES('%s','%s','%s','%s','SUPER_ADMIN','ACTIVE');\n" \
    "$user_id" "$sql_email" "$sql_hash" "$sql_name"
  printf "INSERT INTO audit_logs(id,actor_id,action,resource,resource_id,before_json,after_json,source_service) VALUES('%s',NULL,'INITIAL_SUPER_ADMIN_BOOTSTRAPPED','user','%s',NULL,JSON_OBJECT('role','SUPER_ADMIN','status','ACTIVE'),'operator-bootstrap');\n" \
    "$audit_id" "$user_id"
  printf 'COMMIT;\n'
} > "$sql_file"
chmod 600 "$sql_file"
mysql_admin identity_db < "$sql_file"

[[ "$(mysql_admin identity_db -e "SELECT COUNT(*) FROM users WHERE id='$user_id' AND role='SUPER_ADMIN' AND status='ACTIVE';")" == 1 ]] ||
  fail 'SUPER_ADMIN read-back failed'

printf '%s\n' "$admin_email" > "$email_file"
printf '%s\n' "$admin_password" > "$password_file"
chmod 600 "$email_file" "$password_file"
unset admin_password password_hash

log 'PASS: one active DT SUPER_ADMIN created with Argon2id password hashing'
log "operator credential files: $email_file and $password_file (mode 0600)"
log 'credentials were not written to Git or the deployment log'
