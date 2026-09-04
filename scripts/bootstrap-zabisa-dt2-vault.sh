#!/usr/bin/env bash
set -Eeuo pipefail
set +x
umask 077

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

MODE="${1:---plan}"
NAMESPACE="zabisa-app"
KUBECTL_BIN="${KUBECTL:-kubectl}"
MYSQL_CA_FILE="${MYSQL_SSL_CA:-}"
SHARED_PATH="zabisa/dt/shared/runtime"

fail() {
  printf '[dt2-bootstrap] ERROR: %s\n' "$*" >&2
  exit 1
}

pass() {
  printf '[dt2-bootstrap] PASS: %s\n' "$*"
}

case "$MODE" in
  --plan|--apply|--verify) ;;
  *) fail 'usage: bootstrap-zabisa-dt2-vault.sh --plan|--apply|--verify' ;;
esac

for command_name in "$KUBECTL_BIN" vault openssl python3; do
  command -v "$command_name" >/dev/null 2>&1 || fail "required command missing: $command_name"
done

: "${VAULT_ADDR:?VAULT_ADDR is required}"
[[ -n "$MYSQL_CA_FILE" && -r "$MYSQL_CA_FILE" ]] || fail 'MYSQL_SSL_CA must name the readable MySQL CA PEM'

openssl x509 -in "$MYSQL_CA_FILE" -noout >/dev/null 2>&1 || fail 'MYSQL_SSL_CA is not a valid X.509 certificate'
openssl x509 -in "$MYSQL_CA_FILE" -noout -text | grep -q 'CA:TRUE' || fail 'MYSQL_SSL_CA is not marked CA:TRUE'

vault status >/dev/null
vault token lookup >/dev/null
"$KUBECTL_BIN" config current-context
./scripts/verify-cluster-vault-compat.sh

inspect_shared_secret() {
  if ! vault kv get -mount=kv -format=json "$SHARED_PATH" >/dev/null 2>&1; then
    printf '[dt2-bootstrap] shared runtime secret: ABSENT\n'
    return 1
  fi

  vault kv get -mount=kv -format=json "$SHARED_PATH" |
    python3 -c '
import json, sys
data = json.load(sys.stdin)["data"]["data"]
expected = {"JWT_SIGNING_KEY", "INTERNAL_SERVICE_KEY"}
actual = set(data)
assert actual == expected, f"shared runtime keys mismatch: {sorted(actual)}"
for key in expected:
    assert isinstance(data[key], str) and len(data[key]) >= 32, f"{key} is too short"
print("[dt2-bootstrap] shared runtime secret: VALID")
' || fail 'existing shared runtime secret has an invalid or incomplete field contract'
}

verify_ca_secrets() {
  "$KUBECTL_BIN" -n "$NAMESPACE" get secret vault-ca -o json |
    python3 -c '
import json, sys
data = json.load(sys.stdin).get("data", {})
assert sorted(data) == ["ca.crt"] and data["ca.crt"], "vault-ca must contain only non-empty ca.crt"
'

  "$KUBECTL_BIN" -n "$NAMESPACE" get secret mysql-ca -o json |
    python3 -c '
import json, sys
data = json.load(sys.stdin).get("data", {})
assert sorted(data) == ["ca.pem"] and data["ca.pem"], "mysql-ca must contain only non-empty ca.pem"
'
}

verify_roles() {
  local service role policy expected_sa expected_ttl
  local -a services=(api-gateway identity content student tahfidz academic donation notification)

  for service in "${services[@]}"; do
    role="app-zabisa-${service}-dt"
    policy="zabisa-${service}-dt"
    expected_sa="zabisa-${service}"
    vault policy read "$policy" >/dev/null
    vault read -format=json "auth/kubernetes/role/$role" |
      python3 -c '
import json, sys
d = json.load(sys.stdin)["data"]
assert d["bound_service_account_names"] == [sys.argv[1]]
assert d["bound_service_account_namespaces"] == ["zabisa-app"]
assert d["token_policies"] == [sys.argv[2]]
assert d["audience"] == "vault"
' "$expected_sa" "$policy"
  done

  for service in identity content student tahfidz academic donation notification; do
    role="app-zabisa-${service}-migrator-dt"
    policy="zabisa-${service}-migrator-dt"
    expected_sa="zabisa-${service}-migrator"
    vault policy read "$policy" >/dev/null
    vault read -format=json "auth/kubernetes/role/$role" |
      python3 -c '
import json, sys
d = json.load(sys.stdin)["data"]
assert d["bound_service_account_names"] == [sys.argv[1]]
assert d["bound_service_account_namespaces"] == ["zabisa-app"]
assert d["token_policies"] == [sys.argv[2]]
assert d["audience"] == "vault"
' "$expected_sa" "$policy"
  done
}

echo "[dt2-bootstrap] mode=$MODE namespace=$NAMESPACE"

if [[ "$MODE" == '--plan' ]]; then
  "$KUBECTL_BIN" get namespace "$NAMESPACE" >/dev/null
  if "$KUBECTL_BIN" -n "$NAMESPACE" get secret vault-ca >/dev/null 2>&1; then
    pass 'existing vault-ca is present'
  else
    fail 'zabisa-app/vault-ca is missing; copy the existing trusted CA before apply'
  fi
  if inspect_shared_secret; then
    pass 'shared runtime secret will be preserved'
  else
    echo '[dt2-bootstrap] PLAN: shared runtime secret will be generated once during --apply'
  fi
  echo '[dt2-bootstrap] PLAN: reconcile existing namespace labels, ServiceAccounts, NetworkPolicies and db-dt abstraction'
  echo '[dt2-bootstrap] PLAN: bootstrap MySQL CA from MYSQL_SSL_CA'
  echo '[dt2-bootstrap] PLAN: reconcile 15 least-privilege Vault policies and Kubernetes roles'
  pass 'plan completed; no mutation performed'
  exit 0
fi

if [[ "$MODE" == '--apply' ]]; then
  echo '[dt2-bootstrap] applying repository-owned namespace prerequisites'
  "$KUBECTL_BIN" apply -f deploy/kubernetes/base/platform.yaml >/dev/null
  "$KUBECTL_BIN" apply -f deploy/kubernetes/base/db-dt.yaml >/dev/null

  "$KUBECTL_BIN" -n "$NAMESPACE" get secret vault-ca >/dev/null 2>&1 ||
    fail 'zabisa-app/vault-ca is missing; refusing to create trust material from an unknown source'

  ./scripts/bootstrap-zabisa-mysql-ca.sh "$MYSQL_CA_FILE" >/dev/null

  if inspect_shared_secret; then
    pass 'preserved existing shared runtime secret'
  else
    jwt_key="$(openssl rand -base64 48)"
    internal_key="$(openssl rand -base64 48)"
    vault kv put -mount=kv "$SHARED_PATH" \
      JWT_SIGNING_KEY="$jwt_key" \
      INTERNAL_SERVICE_KEY="$internal_key" >/dev/null
    unset jwt_key internal_key
    pass 'created shared runtime secret without displaying its values'
  fi

  ./scripts/configure-zabisa-vault-auth.sh
  ./scripts/configure-zabisa-vault-migrator-auth.sh
fi

inspect_shared_secret
verify_ca_secrets
verify_roles

"$KUBECTL_BIN" -n "$NAMESPACE" get service db-dt >/dev/null
"$KUBECTL_BIN" -n "$NAMESPACE" get endpointslice db-dt-external >/dev/null
"$KUBECTL_BIN" -n "$NAMESPACE" get networkpolicy \
  default-deny allow-dns-egress allow-vault-egress allow-mysql-egress >/dev/null

pass 'CA secrets, shared KV, ServiceAccounts, NetworkPolicies and Vault roles are consistent'
