#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
fail(){ echo "[kubectl-override] ERROR: $*" >&2; exit 1; }
pass(){ echo "[kubectl-override] OK: $*"; }

scripts=(
  scripts/verify-cluster-vault-compat.sh
  scripts/bootstrap-zabisa-platform-prereqs.sh
  scripts/bootstrap-zabisa-vault-ca.sh
  scripts/apply-hotfix-0.1-0.2.sh
)
for f in "${scripts[@]}"; do
  [[ -f "$f" ]] || fail "missing $f"
  grep -q 'KUBECTL_BIN="${KUBECTL:-kubectl}"' "$f" || fail "$f does not honor KUBECTL override"
done

# No executable cluster command in these scripts may bypass KUBECTL_BIN.
if grep -nE '^[[:space:]]*kubectl[[:space:]]|[|;&][[:space:]]*kubectl[[:space:]]' "${scripts[@]}"; then
  fail 'literal kubectl invocation remains in cluster mutation/verification scripts'
fi
pass 'cluster scripts honor KUBECTL override and contain no direct kubectl invocation'

bash -n "${scripts[@]}"
pass 'shell syntax'
echo '[kubectl-override] PASS: explicit kubectl binary selection is internally consistent.'
