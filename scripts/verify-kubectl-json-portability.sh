#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if grep -RInE --include='*.sh' 'jsonpath=.*\$k,\$v' scripts >/tmp/zabisa-invalid-jsonpath.$$ 2>/dev/null; then
  echo '[kubectl-json] ERROR: unsupported kubectl JSONPath map-variable syntax remains:' >&2
  cat /tmp/zabisa-invalid-jsonpath.$$ >&2
  rm -f /tmp/zabisa-invalid-jsonpath.$$
  exit 1
fi
rm -f /tmp/zabisa-invalid-jsonpath.$$

echo '[kubectl-json] OK: no unsupported kubectl JSONPath map-variable syntax remains'
bash -n scripts/bootstrap-zabisa-vault-ca.sh scripts/bootstrap-zabisa-platform-prereqs.sh
echo '[kubectl-json] OK: bootstrap shell syntax'
echo '[kubectl-json] PASS: Vault CA bootstrap uses portable JSON inspection.'
