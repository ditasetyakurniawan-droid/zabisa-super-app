#!/usr/bin/env bash
set -Eeuo pipefail
set +x
umask 077

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

MODE="${1:---source}"
case "$MODE" in
  --source|--live) ;;
  *)
    echo "usage: $0 [--source|--live]" >&2
    exit 64
    ;;
esac

log() { printf '[db-vault-verify] %s\n' "$*"; }
fail() { printf '[db-vault-verify] ERROR: %s\n' "$*" >&2; exit 1; }

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

sql_template='deploy/local/mysql/01-zabisa-users.sql'
provisioner='scripts/provision-zabisa-mysql-vault.sh'
compose_file='docker-compose.yml'
docker_mysql_client='scripts/mysql-client-docker.sh'

source_verify() {
  [[ -f "$sql_template" ]] || fail "$sql_template is missing"
  [[ -x "$provisioner" ]] || fail "$provisioner is missing or not executable"
  [[ -x "$docker_mysql_client" ]] || fail "$docker_mysql_client is missing or not executable"
  bash -n "$provisioner" || fail 'provisioner shell syntax is invalid'
  bash -n "$docker_mysql_client" || fail 'Docker MySQL client wrapper shell syntax is invalid'
  bash -n "$0" || fail 'verifier shell syntax is invalid'

  grep -Fq "'\${MYSQL_ACCOUNT_HOST}'" "$sql_template" || fail 'bounded account-host template placeholder is missing'
  if grep -Fq "@'%'" "$sql_template"; then fail 'wildcard MySQL account host is forbidden'; fi
  if grep -Eq 'GRANT[[:space:]]+ALL' "$sql_template"; then fail 'GRANT ALL is forbidden'; fi
  if grep -Fq 'FLUSH PRIVILEGES' "$sql_template"; then fail 'manual FLUSH PRIVILEGES is unnecessary and forbidden'; fi

  require_ssl_count="$(grep -Ec 'REQUIRE SSL' "$sql_template")"
  [[ "$require_ssl_count" -eq 28 ]] || fail "expected 28 REQUIRE SSL clauses; found $require_ssl_count"
  revoke_count="$(grep -Ec '^REVOKE ALL PRIVILEGES, GRANT OPTION FROM ' "$sql_template")"
  [[ "$revoke_count" -eq 14 ]] || fail "expected 14 exact privilege resets; found $revoke_count"

  for service in "${services[@]}"; do
    database="${databases[$service]}"
    runtime_user="zabisa_${service}_app"
    migrator_user="zabisa_${service}_migrator"
    upper="${service^^}"

    grep -Fq "CREATE DATABASE IF NOT EXISTS $database CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" "$sql_template" || fail "$database definition is missing"
    grep -Fq "CREATE USER IF NOT EXISTS '$runtime_user'" "$sql_template" || fail "$runtime_user creation is missing"
    grep -Fq "ALTER USER '$runtime_user'" "$sql_template" || fail "$runtime_user reconciliation is missing"
    grep -Fq "GRANT SELECT, INSERT, UPDATE, DELETE ON $database.* TO '$runtime_user'" "$sql_template" || fail "$runtime_user grant is incorrect"
    grep -Fq "\${${upper}_APP_PASSWORD}" "$sql_template" || fail "$runtime_user password placeholder is missing"

    grep -Fq "CREATE USER IF NOT EXISTS '$migrator_user'" "$sql_template" || fail "$migrator_user creation is missing"
    grep -Fq "ALTER USER '$migrator_user'" "$sql_template" || fail "$migrator_user reconciliation is missing"
    grep -Fq "GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, ALTER, INDEX, REFERENCES ON $database.* TO '$migrator_user'" "$sql_template" || fail "$migrator_user grant is incorrect"
    grep -Fq "\${${upper}_MIGRATOR_PASSWORD}" "$sql_template" || fail "$migrator_user password placeholder is missing"

    grep -Fq "kv/data/zabisa/dt/$service/database" "deploy/kubernetes/base/$service.yaml" || fail "runtime manifest Vault path mismatch for $service"
    grep -Fq "kv/data/zabisa/dt/$service/migrator" deploy/kubernetes/base/migrations.yaml || fail "migration manifest Vault path mismatch for $service"
    grep -Fq "kv/data/zabisa/dt/$service/migrator" "deploy/vault/policies/zabisa-${service}-migrator-dt.hcl" || fail "migrator policy Vault path mismatch for $service"
  done

  grep -Fq '"zabisa/dt/$service/database"' "$provisioner" || fail 'dynamic runtime Vault path mapping is missing'
  grep -Fq '"zabisa/dt/$service/migrator"' "$provisioner" || fail 'dynamic migrator Vault path mapping is missing'
  if grep -Fq 'kv/zabisa/dt/runtime/' "$provisioner"; then fail 'legacy runtime-first Vault path is forbidden'; fi
  if grep -Eq -- '(^|[[:space:]])-p([^[:space:]]|$)|--password(=|[[:space:]])' "$provisioner" "$0"; then
    fail 'MySQL password must not be passed on the process command line'
  fi
  grep -Fq -- '--defaults-extra-file=' "$provisioner" || fail 'protected MySQL option file is required'
  grep -Fq 'ssl-mode=VERIFY_CA' "$provisioner" || fail 'MySQL admin VERIFY_CA is required'
  grep -Fq 'MYSQL_CLIENT_BIN' "$provisioner" || fail 'explicit MySQL client selection is required'
  grep -Fq -- '--entrypoint mysql' "$docker_mysql_client" || fail 'Docker wrapper must invoke the Oracle mysql entrypoint directly'
  grep -Fq 'mysql@sha256:' "$docker_mysql_client" || fail 'Docker MySQL client image must be pinned by digest'
  grep -Fq 'MYSQL_PASSWORD=-' "$provisioner" || fail 'Vault password must be supplied via stdin'
  grep -Fq 'set +x' "$provisioner" || fail 'provisioner must disable shell xtrace'
  grep -Fq 'set +x' "$0" || fail 'verifier must disable shell xtrace'
  grep -Fq './deploy/local/mysql/00-databases.sql:/docker-entrypoint-initdb.d/00-databases.sql:ro' "$compose_file" \
    || fail 'Docker Compose must mount only the local database bootstrap SQL'
  if grep -Fq './deploy/local/mysql:/docker-entrypoint-initdb.d' "$compose_file"; then
    fail 'Docker Compose must not auto-execute the DT account provisioning template'
  fi

  log 'PASS: SQL, bounded MySQL account sources, TLS, least privilege, Compose isolation, Vault paths and secret handling'
}

source_verify
[[ "$MODE" == '--source' ]] && exit 0

for required in vault python3 mktemp stat; do
  command -v "$required" >/dev/null 2>&1 || fail "$required is required for --live"
done

MYSQL_ADMIN_HOST="${MYSQL_ADMIN_HOST:-db-dt}"
MYSQL_ADMIN_PORT="${MYSQL_ADMIN_PORT:-3306}"
MYSQL_ADMIN_USER="${MYSQL_ADMIN_USER:-root}"
MYSQL_ACCOUNT_NETWORKS="${MYSQL_ACCOUNT_NETWORKS:-}"
MYSQL_ADMIN_PASSWORD_FILE="${MYSQL_ADMIN_PASSWORD_FILE:-}"
MYSQL_SSL_CA="${MYSQL_SSL_CA:-}"
MYSQL_CLIENT_BIN="${MYSQL_CLIENT_BIN:-mysql}"
VAULT_KV_MOUNT="${VAULT_KV_MOUNT:-kv}"

[[ -n "$MYSQL_ACCOUNT_NETWORKS" ]] || fail 'set MYSQL_ACCOUNT_NETWORKS for --live'
[[ -f "$MYSQL_ADMIN_PASSWORD_FILE" && -r "$MYSQL_ADMIN_PASSWORD_FILE" ]] || fail 'MYSQL_ADMIN_PASSWORD_FILE is not readable'
[[ -f "$MYSQL_SSL_CA" && -r "$MYSQL_SSL_CA" ]] || fail 'MYSQL_SSL_CA is not readable'
command -v "$MYSQL_CLIENT_BIN" >/dev/null 2>&1 || fail "MYSQL_CLIENT_BIN is not executable: $MYSQL_CLIENT_BIN"
if ! "$MYSQL_CLIENT_BIN" --no-defaults --help 2>&1 | grep -Fq -- '--ssl-mode'; then
  fail 'MYSQL_CLIENT_BIN must be an Oracle MySQL client with --ssl-mode support; MariaDB clients are unsupported'
fi
: "${VAULT_ADDR:?set VAULT_ADDR}"
: "${VAULT_CACERT:?set VAULT_CACERT}"
[[ "$VAULT_ADDR" == https://* ]] || fail 'VAULT_ADDR must use https://'
[[ -f "$VAULT_CACERT" && -r "$VAULT_CACERT" ]] || fail 'VAULT_CACERT is not readable'

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

print(','.join(normalized))
PY
}

account_hosts_csv="$(normalize_account_networks "$MYSQL_ACCOUNT_NETWORKS")" \
  || fail 'MYSQL_ACCOUNT_NETWORKS must contain canonical IPv4 CIDRs or exact IPv4 addresses with prefix /16 or narrower'
[[ -n "$account_hosts_csv" ]] || fail 'no valid MYSQL_ACCOUNT_NETWORKS entries were provided'

password_permissions="$(stat -c '%a' "$MYSQL_ADMIN_PASSWORD_FILE")"
if (( (8#$password_permissions & 077) != 0 )); then
  fail "MYSQL_ADMIN_PASSWORD_FILE must not be group/world accessible; current mode is $password_permissions"
fi

escape_option_value() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  printf '"%s"' "$value"
}

mysql_admin_password="$(<"$MYSQL_ADMIN_PASSWORD_FILE")"
[[ -n "$mysql_admin_password" ]] || fail 'MYSQL_ADMIN_PASSWORD_FILE is empty'

temp_dir="$(mktemp -d "${TMPDIR:-/tmp}/zabisa-db-verify.XXXXXX")"
mysql_defaults="$temp_dir/mysql-client.cnf"
schemas_report="$temp_dir/schemas.tsv"
accounts_report="$temp_dir/accounts.tsv"
schema_privileges_report="$temp_dir/schema-privileges.tsv"
global_privileges_report="$temp_dir/global-privileges.tsv"
role_edges_report="$temp_dir/role-edges.tsv"
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

mysql_admin() {
  "$MYSQL_CLIENT_BIN" --defaults-extra-file="$mysql_defaults" --batch --skip-column-names "$@"
}

ssl_cipher="$(mysql_admin -e "SHOW SESSION STATUS LIKE 'Ssl_cipher';" | awk 'NR==1 {print $2}')"
[[ -n "$ssl_cipher" ]] || fail 'MySQL live verification session is not encrypted'
log "MySQL VERIFY_CA session established; cipher=$ssl_cipher"

mysql_admin -e "SELECT schema_name, default_character_set_name, default_collation_name FROM information_schema.schemata WHERE schema_name REGEXP '^(identity|content|student|tahfidz|academic|donation|notification)_db$' ORDER BY schema_name;" > "$schemas_report"
mysql_admin -e "SELECT user, host, ssl_type FROM mysql.user WHERE user REGEXP '^zabisa_' ORDER BY user, host;" > "$accounts_report"
mysql_admin -e "SELECT grantee, table_schema, privilege_type FROM information_schema.schema_privileges WHERE grantee REGEXP \"'zabisa_\" ORDER BY grantee, table_schema, privilege_type;" > "$schema_privileges_report"
mysql_admin -e "SELECT grantee, privilege_type FROM information_schema.user_privileges WHERE grantee REGEXP \"'zabisa_\" ORDER BY grantee, privilege_type;" > "$global_privileges_report"
mysql_admin -e "SELECT to_user, to_host FROM mysql.role_edges WHERE to_user REGEXP '^zabisa_' ORDER BY to_user, to_host;" > "$role_edges_report"

python3 - "$schemas_report" "$accounts_report" "$schema_privileges_report" "$global_privileges_report" "$role_edges_report" "$account_hosts_csv" <<'PY' || fail 'live MySQL privilege matrix verification failed'
import pathlib
import sys

schema_file, account_file, schema_privilege_file, global_privilege_file, role_edge_file, host_csv = sys.argv[1:]
services = ('identity', 'content', 'student', 'tahfidz', 'academic', 'donation', 'notification')
hosts = {value.strip() for value in host_csv.split(',') if value.strip()}
expected_schemas = {f'{service}_db': ('utf8mb4', 'utf8mb4_unicode_ci') for service in services}

actual_schemas = {}
for line in pathlib.Path(schema_file).read_text(encoding='utf-8').splitlines():
    schema, charset, collation = line.split('\t')
    actual_schemas[schema] = (charset, collation)
assert actual_schemas == expected_schemas, f'schema mismatch: {actual_schemas}'

expected_accounts = {
    (f'zabisa_{service}_{kind}', host): 'ANY'
    for service in services
    for kind in ('app', 'migrator')
    for host in hosts
}
actual_accounts = {}
for line in pathlib.Path(account_file).read_text(encoding='utf-8').splitlines():
    user, host, ssl_type = line.split('\t')
    actual_accounts[(user, host)] = ssl_type
assert actual_accounts == expected_accounts, f'account/TLS mismatch: {actual_accounts}'

runtime_privileges = {'SELECT', 'INSERT', 'UPDATE', 'DELETE'}
migrator_privileges = runtime_privileges | {'CREATE', 'ALTER', 'INDEX', 'REFERENCES'}
expected_schema_privileges = set()
for service in services:
    database = f'{service}_db'
    for host in hosts:
        expected_schema_privileges |= {
            (f"'zabisa_{service}_app'@'{host}'", database, privilege)
            for privilege in runtime_privileges
        }
        expected_schema_privileges |= {
            (f"'zabisa_{service}_migrator'@'{host}'", database, privilege)
            for privilege in migrator_privileges
        }

actual_schema_privileges = {
    tuple(line.split('\t'))
    for line in pathlib.Path(schema_privilege_file).read_text(encoding='utf-8').splitlines()
    if line
}
assert actual_schema_privileges == expected_schema_privileges, 'schema privilege set differs from the least-privilege contract'

actual_global_privileges = {
    tuple(line.split('\t'))
    for line in pathlib.Path(global_privilege_file).read_text(encoding='utf-8').splitlines()
    if line
}
expected_global_privileges = {
    (f"'zabisa_{service}_{kind}'@'{host}'", 'USAGE')
    for service in services
    for kind in ('app', 'migrator')
    for host in hosts
}
assert actual_global_privileges == expected_global_privileges, 'unexpected global privilege detected'

role_edges = pathlib.Path(role_edge_file).read_text(encoding='utf-8').strip()
assert not role_edges, f'unexpected MySQL role assignment detected: {role_edges}'
PY
log 'MySQL databases, bounded account sources, REQUIRE SSL and privilege matrix verified'

vault status >/dev/null
vault token lookup >/dev/null
for service in "${services[@]}"; do
  for kind in database migrator; do
    if [[ "$kind" == database ]]; then
      expected_user="zabisa_${service}_app"
    else
      expected_user="zabisa_${service}_migrator"
    fi
    path="zabisa/dt/$service/$kind"
    actual_user="$(vault kv get -mount="$VAULT_KV_MOUNT" -field=MYSQL_USER "$path")"
    [[ "$actual_user" == "$expected_user" ]] || fail "Vault $VAULT_KV_MOUNT/$path MYSQL_USER mismatch"
    password="$(vault kv get -mount="$VAULT_KV_MOUNT" -field=MYSQL_PASSWORD "$path")"
    [[ "$password" =~ ^[[:xdigit:]]{64}$ ]] || fail "Vault $VAULT_KV_MOUNT/$path MYSQL_PASSWORD format mismatch"
    unset password
  done
  log "Vault runtime/migrator fields verified for $service"
done

log 'PASS: live MySQL and Vault database credential boundary is internally consistent'
