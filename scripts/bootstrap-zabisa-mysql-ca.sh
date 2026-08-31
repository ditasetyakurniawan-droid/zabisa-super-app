#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

KUBECTL="${KUBECTL:-kubectl}"
CA_FILE="${1:-}"
[[ -n "$CA_FILE" ]] || { echo 'usage: bootstrap-zabisa-mysql-ca.sh /path/to/mysql-ca.pem' >&2; exit 64; }
[[ -r "$CA_FILE" ]] || { echo "[mysql-ca] ERROR: cannot read $CA_FILE" >&2; exit 1; }
command -v openssl >/dev/null 2>&1 || { echo '[mysql-ca] ERROR: openssl is required' >&2; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo '[mysql-ca] ERROR: python3 is required' >&2; exit 1; }

openssl x509 -in "$CA_FILE" -noout >/dev/null 2>&1 || { echo '[mysql-ca] ERROR: input is not a parseable X.509 certificate' >&2; exit 1; }
if ! openssl x509 -in "$CA_FILE" -noout -text | grep -q 'CA:TRUE'; then
  echo '[mysql-ca] ERROR: certificate is not marked CA:TRUE' >&2
  exit 1
fi

"$KUBECTL" get ns zabisa-app >/dev/null
"$KUBECTL" -n zabisa-app create secret generic mysql-ca \
  --from-file=ca.pem="$CA_FILE" \
  --dry-run=client -o yaml | "$KUBECTL" apply -f -

"$KUBECTL" -n zabisa-app get secret mysql-ca -o json | python3 -c '
import json,sys
obj=json.load(sys.stdin)
data=obj.get("data",{})
assert sorted(data)==["ca.pem"], f"unexpected mysql-ca keys: {sorted(data)}"
assert bool(data["ca.pem"]), "mysql-ca ca.pem is empty"
print("[mysql-ca] PASS: zabisa-app/mysql-ca contains exactly ca.pem; certificate bytes were not printed.")
'
