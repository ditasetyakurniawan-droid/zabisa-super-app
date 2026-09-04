#!/usr/bin/env bash
set -Eeuo pipefail
set +x
umask 077

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

MODE="${1:---plan}"
case "$MODE" in
  --plan|--apply|--rotate) ;;
  *)
    echo "usage: $0 [--plan|--apply|--rotate]" >&2
    exit 64
    ;;
esac

log() { printf '[db-vault-provision] %s\n' "$*"; }
fail() { printf '[db-vault-provision] ERROR: %s\n' "$*" >&2; exit 1; }

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "$1 is required"
}

require_file() {
  [[ -f "$1" && -r "$1" ]] || fail "$2 is not a readable regular file: $1"
}

escape_option_value() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  printf '"%s"' "$value"
}

services=(identity content student tahfidz academic donation notification)
declare -A databases=(
  [identity]=identity_db
  [content]=content_db
  [student]=student_db
  [tahfidz]=tahfidz_db
  [academic]=academic_db
  [donation]=donation_db
  [notification]=notification_db
)

MYSQL_ADMIN_HOST="${MYSQL_ADMIN_HOST:-db-dt}"
MYSQL_ADMIN_PORT="${MYSQL_ADMIN_PORT:-3306}"
MYSQL_ADMIN_USER="${MYSQL_ADMIN_USER:-root}"
MYSQL_ACCOUNT_NETWORKS="${MYSQL_ACCOUNT_NETWORKS:-}"
MYSQL_ADMIN_PASSWORD_FILE="${MYSQL_ADMIN_PASSWORD_FILE:-}"
MYSQL_SSL_CA="${MYSQL_SSL_CA:-}"
MYSQL_CLIENT_BIN="${MYSQL_CLIENT_BIN:-mysql}"
VAULT_KV_MOUNT="${VAULT_KV_MOUNT:-kv}"

[[ "$MYSQL_ADMIN_PORT" =~ ^[0-9]+$ ]] || fail 'MYSQL_ADMIN_PORT must be numeric'
(( MYSQL_ADMIN_PORT >= 1 && MYSQL_ADMIN_PORT <= 65535 )) || fail 'MYSQL_ADMIN_PORT is outside 1..65535'
[[ -n "$MYSQL_ACCOUNT_NETWORKS" ]] || fail 'set MYSQL_ACCOUNT_NETWORKS to comma-separated IPv4 CIDRs or exact IPv4 addresses; wildcard hosts are forbidden'
[[ -n "$MYSQL_ADMIN_PASSWORD_FILE" ]] || fail 'set MYSQL_ADMIN_PASSWORD_FILE; plaintext MYSQL_ADMIN_PASSWORD is intentionally unsupported'
[[ -n "$MYSQL_SSL_CA" ]] || fail 'set MYSQL_SSL_CA to the pinned MySQL CA PEM file'
: "${VAULT_ADDR:?set VAULT_ADDR to the existing Vault HTTPS endpoint}"
: "${VAULT_CACERT:?set VAULT_CACERT to the existing Vault CA PEM file}"
[[ "$VAULT_ADDR" == https://* ]] || fail 'VAULT_ADDR must use https://'
[[ "$VAULT_KV_MOUNT" =~ ^[A-Za-z0-9._-]+$ ]] || fail 'VAULT_KV_MOUNT contains unsupported characters'

require_file deploy/local/mysql/01-zabisa-users.sql 'SQL template'
require_file "$MYSQL_ADMIN_PASSWORD_FILE" 'MySQL admin password file'
require_file "$MYSQL_SSL_CA" 'MySQL CA'
require_file "$VAULT_CACERT" 'Vault CA'

require_command "$MYSQL_CLIENT_BIN"
if ! "$MYSQL_CLIENT_BIN" --no-defaults --help 2>&1 | grep -Fq -- '--ssl-mode'; then
  fail "MYSQL_CLIENT_BIN must be an Oracle MySQL client with --ssl-mode support; MariaDB clients are unsupported"
fi

for required in vault openssl python3 mktemp stat flock; do
  require_command "$required"
done

password_permissions="$(stat -c '%a' "$MYSQL_ADMIN_PASSWORD_FILE")"
if (( (8#$password_permissions & 077) != 0 )); then
  fail "MYSQL_ADMIN_PASSWORD_FILE must not be group/world accessible; current mode is $password_permissions"
fi

mysql_admin_password="$(<"$MYSQL_ADMIN_PASSWORD_FILE")"
[[ -n "$mysql_admin_password" ]] || fail 'MYSQL_ADMIN_PASSWORD_FILE is empty'
[[ "$mysql_admin_password" != *$'\n'* && "$mysql_admin_password" != *$'\r'* ]] || fail 'MySQL admin password must be a single line'

temp_dir="$(mktemp -d "${TMPDIR:-/tmp}/zabisa-db-vault.XXXXXX")"
mysql_defaults="$temp_dir/mysql-client.cnf"
accounts_report="$temp_dir/existing-accounts.tsv"

cleanup() {
  unset mysql_admin_password
  rm -rf -- "$temp_dir"
}
trap cleanup EXIT

{
  printf '[client]\n'
  printf 'protocol=TCP\n'
  printf 'host=%s\n' "$(escape_option_value "$MYSQL_ADMIN_HOST")"
  printf 'port=%s\n' "$MYSQL_ADMIN_PORT"
  printf 'user=%s\n' "$(escape_option_value "$MYSQL_ADMIN_USER")"
  printf 'password=%s\n' "$(escape_option_value "$mysql_admin_password")"
  printf 'ssl-mode=VERIFY_CA\n'
  printf 'ssl-ca=%s\n' "$(escape_option_value "$MYSQL_SSL_CA")"
} > "$mysql_defaults"
chmod 600 "$mysql_defaults"
unset mysql_admin_password

lock_file="${XDG_RUNTIME_DIR:-/tmp}/zabisa-mysql-vault-provision.lock"
exec 9>"$lock_file"
flock -n 9 || fail "another provisioning process holds $lock_file"

normalize_account_networks() {
  python3 - "$1" <<'PY'
import ipaddress
import sys

values = sys.argv[1].split(',')
if not values or any(not value.strip() for value in values):
    raise SystemExit('MYSQL_ACCOUNT_NETWORKS contains an empty entry')

normalized = []
seen = set()
for value in values:
    source = value.strip()
    try:
        network = ipaddress.IPv4Network(
            source if '/' in source else f'{source}/32',
            strict=True,
        )
    except ValueError as exc:
        raise SystemExit(f'invalid canonical IPv4 source {source!r}: {exc}') from exc

    if network.prefixlen < 16:
        raise SystemExit(
            f'IPv4 source {source!r} is broader than the minimum allowed /16'
        )

    if network.prefixlen == 32:
        account_host = str(network.network_address)
    else:
        account_host = f'{network.network_address}/{network.netmask}'

    if account_host not in seen:
        normalized.append(account_host)
        seen.add(account_host)

print('\n'.join(normalized))
PY
}

normalized_account_hosts="$(normalize_account_networks "$MYSQL_ACCOUNT_NETWORKS")" \
  || fail 'MYSQL_ACCOUNT_NETWORKS must contain canonical IPv4 CIDRs or exact IPv4 addresses with prefix /16 or narrower'
[[ -n "$normalized_account_hosts" ]] || fail 'no valid MYSQL_ACCOUNT_NETWORKS entries were provided'
mapfile -t account_hosts <<< "$normalized_account_hosts"
account_hosts_csv="$(IFS=,; printf '%s' "${account_hosts[*]}")"

mysql_admin() {
  "$MYSQL_CLIENT_BIN" --defaults-extra-file="$mysql_defaults" --batch --skip-column-names "$@"
}

log 'checking MySQL TLS connection'
mysql_version="$(mysql_admin -e 'SELECT VERSION();')"
ssl_cipher="$(mysql_admin -e "SHOW SESSION STATUS LIKE 'Ssl_cipher';" | awk 'NR==1 {print $2}')"
[[ -n "$ssl_cipher" ]] || fail 'MySQL admin session is not encrypted'
log "MySQL reachable with VERIFY_CA; server=$mysql_version; cipher=$ssl_cipher"

log 'checking Vault TLS and operator token'
vault status >/dev/null
vault token lookup >/dev/null
log 'Vault reachable and token is valid'

mysql_admin -e "SELECT user, host FROM mysql.user WHERE user REGEXP '^zabisa_' ORDER BY user, host;" > "$accounts_report"
python3 - "$accounts_report" "$account_hosts_csv" <<'PY' || fail 'unexpected or wildcard Zabisa MySQL account already exists'
import pathlib
import sys

services = ('identity', 'content', 'student', 'tahfidz', 'academic', 'donation', 'notification')
allowed_users = {f'zabisa_{service}_{kind}' for service in services for kind in ('app', 'migrator')}
allowed_hosts = {value.strip() for value in sys.argv[2].split(',') if value.strip()}
unexpected = []
for line in pathlib.Path(sys.argv[1]).read_text(encoding='utf-8').splitlines():
    user, host = line.split('\t', 1)
    if user not in allowed_users or host not in allowed_hosts:
        unexpected.append(f'{user}@{host}')
if unexpected:
    print('[db-vault-provision] unmanaged accounts: ' + ', '.join(unexpected), file=sys.stderr)
    raise SystemExit(1)
PY

log "mode=$MODE"
log "bounded MySQL account sources: ${account_hosts[*]}"
for service in "${services[@]}"; do
  log "plan $service: ${databases[$service]} | zabisa_${service}_app -> $VAULT_KV_MOUNT/zabisa/dt/$service/database | zabisa_${service}_migrator -> $VAULT_KV_MOUNT/zabisa/dt/$service/migrator"
done

if [[ "$MODE" == '--plan' ]]; then
  log 'PLAN PASS: connectivity, TLS, account scope and target paths are valid; no mutation performed'
  exit 0
fi

declare -A runtime_passwords=()
declare -A migrator_passwords=()

read_or_generate_password() {
  local path="$1"
  local expected_user="$2"
  local rotate="$3"
  local existing_user
  local password
  local error_file

  if [[ "$rotate" == 'true' ]]; then
    openssl rand -hex 32
    return
  fi

  error_file="$temp_dir/vault-get-${path//\//_}.err"
  if vault kv get -mount="$VAULT_KV_MOUNT" "$path" >/dev/null 2>"$error_file"; then
    existing_user="$(vault kv get -mount="$VAULT_KV_MOUNT" -field=MYSQL_USER "$path")"
    [[ "$existing_user" == "$expected_user" ]] || fail "Vault $VAULT_KV_MOUNT/$path has unexpected MYSQL_USER"
    password="$(vault kv get -mount="$VAULT_KV_MOUNT" -field=MYSQL_PASSWORD "$path")"
    [[ "$password" =~ ^[[:xdigit:]]{64}$ ]] || fail "Vault $VAULT_KV_MOUNT/$path MYSQL_PASSWORD is not a 64-character hexadecimal credential"
    printf '%s\n' "$password"
    return
  fi

  if grep -Fq 'No value found' "$error_file"; then
    openssl rand -hex 32
    return
  fi

  fail "cannot read Vault $VAULT_KV_MOUNT/$path; refusing to treat an authorization or transport error as a missing secret"
}

rotate=false
[[ "$MODE" == '--rotate' ]] && rotate=true

for service in "${services[@]}"; do
  runtime_user="zabisa_${service}_app"
  migrator_user="zabisa_${service}_migrator"
  runtime_passwords["$service"]="$(read_or_generate_password "zabisa/dt/$service/database" "$runtime_user" "$rotate")"
  migrator_passwords["$service"]="$(read_or_generate_password "zabisa/dt/$service/migrator" "$migrator_user" "$rotate")"
done

render_sql_for_host() {
  local account_host="$1"
  local line
  local service
  local upper
  local runtime_placeholder
  local migrator_placeholder

  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line//\$\{MYSQL_ACCOUNT_HOST\}/$account_host}"
    for service in "${services[@]}"; do
      upper="${service^^}"
      runtime_placeholder="\${${upper}_APP_PASSWORD}"
      migrator_placeholder="\${${upper}_MIGRATOR_PASSWORD}"
      line="${line//"$runtime_placeholder"/${runtime_passwords[$service]}}"
      line="${line//"$migrator_placeholder"/${migrator_passwords[$service]}}"
    done
    [[ "$line" != *'${'* ]] || fail "unresolved SQL template placeholder for account host $account_host"
    printf '%s\n' "$line"
  done < deploy/local/mysql/01-zabisa-users.sql
}

log 'applying databases, bounded-source accounts, TLS requirements and least-privilege grants'
{
  for account_host in "${account_hosts[@]}"; do
    render_sql_for_host "$account_host"
  done
} | mysql_admin
log 'MySQL provisioning completed'

log 'writing runtime and migrator credentials to Vault KV v2'
for service in "${services[@]}"; do
  runtime_user="zabisa_${service}_app"
  migrator_user="zabisa_${service}_migrator"
  printf '%s' "${runtime_passwords[$service]}" |
    vault kv put -mount="$VAULT_KV_MOUNT" "zabisa/dt/$service/database" \
      MYSQL_USER="$runtime_user" MYSQL_PASSWORD=- >/dev/null
  printf '%s' "${migrator_passwords[$service]}" |
    vault kv put -mount="$VAULT_KV_MOUNT" "zabisa/dt/$service/migrator" \
      MYSQL_USER="$migrator_user" MYSQL_PASSWORD=- >/dev/null
  log "Vault credentials written for $service"
done

unset runtime_passwords migrator_passwords

MYSQL_ACCOUNT_NETWORKS="$account_hosts_csv" \
MYSQL_ADMIN_HOST="$MYSQL_ADMIN_HOST" \
MYSQL_ADMIN_PORT="$MYSQL_ADMIN_PORT" \
MYSQL_ADMIN_USER="$MYSQL_ADMIN_USER" \
MYSQL_ADMIN_PASSWORD_FILE="$MYSQL_ADMIN_PASSWORD_FILE" \
MYSQL_SSL_CA="$MYSQL_SSL_CA" \
MYSQL_CLIENT_BIN="$MYSQL_CLIENT_BIN" \
VAULT_KV_MOUNT="$VAULT_KV_MOUNT" \
  ./scripts/verify-zabisa-mysql-vault-provision.sh --live

log 'PASS: MySQL security boundary and Vault database credentials are synchronized'
