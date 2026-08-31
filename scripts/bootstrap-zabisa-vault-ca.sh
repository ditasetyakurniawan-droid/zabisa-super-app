#!/usr/bin/env bash
set -euo pipefail

KUBECTL_BIN="${KUBECTL:-kubectl}"

SRC_NS="${1:-}"
DST_NS="${2:-zabisa-app}"
[[ -n "$SRC_NS" ]] || { echo "usage: $0 <source-namespace-with-vault-ca> [destination-namespace]" >&2; exit 64; }
command -v "$KUBECTL_BIN" >/dev/null 2>&1 || { echo "[vault-ca] ERROR: kubectl executable not found: $KUBECTL_BIN" >&2; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "[vault-ca] ERROR: python3 is required for portable Secret metadata inspection" >&2; exit 1; }

"$KUBECTL_BIN" get namespace "$DST_NS" >/dev/null 2>&1 || {
  echo "[vault-ca] ERROR: destination namespace $DST_NS does not exist; apply platform bootstrap first" >&2
  exit 1
}

# Do not use kubectl JSONPath map-variable syntax here. kubectl's JSONPath dialect does
# not support Go-template-style "$k,$v :=" assignment consistently. Inspect only key
# names through JSON; secret values are never printed or stored in shell variables.
keys="$("$KUBECTL_BIN" -n "$SRC_NS" get secret vault-ca -o json \
  | python3 -c 'import json,sys; d=json.load(sys.stdin).get("data",{}); print("\n".join(sorted(d.keys())))')"
[[ "$keys" == "ca.crt" ]] || {
  display_keys="${keys//$'\n'/,}"
  [[ -n "$display_keys" ]] || display_keys="<none>"
  echo "[vault-ca] ERROR: source $SRC_NS/vault-ca must contain only ca.crt; got keys: $display_keys" >&2
  exit 1
}

# Secret bytes never pass through shell variables or stdout intended for a human.
# Metadata is stripped and namespace changed in-stream.
"$KUBECTL_BIN" -n "$SRC_NS" get secret vault-ca -o json \
  | python3 -c 'import json,sys; s=json.load(sys.stdin); s["metadata"]={"name":"vault-ca","namespace":sys.argv[1]}; s.pop("immutable",None); print(json.dumps(s))' "$DST_NS" \
  | "$KUBECTL_BIN" apply -f - >/dev/null

# Verify shape without exposing certificate bytes.
"$KUBECTL_BIN" -n "$DST_NS" get secret vault-ca -o json \
  | python3 -c 'import json,sys; d=json.load(sys.stdin).get("data",{}); assert sorted(d.keys())==["ca.crt"] and bool(d["ca.crt"]), "vault-ca must contain one non-empty ca.crt key"'

echo "[vault-ca] PASS: copied CA-only secret $SRC_NS/vault-ca -> $DST_NS/vault-ca without printing certificate data."
