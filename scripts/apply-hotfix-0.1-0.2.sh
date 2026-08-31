#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
KUBECTL_BIN="${KUBECTL:-kubectl}"

printf '[hotfix] repository: %s\n' "$ROOT"

# Never delete dependency lock files. node_modules is generated and intentionally ignored.
rm -rf \
  apps/mobile/android/app/.cxx \
  apps/mobile/android/.gradle \
  apps/admin-web/test-results \
  scripts/__pycache__
find . -type f \( -name '*.tsbuildinfo' -o -name '*.bak' -o -name '*.bak-*' -o -name '*.pyc' \) -delete

# Safety assertions: namespace must be isolated and old deployment namespace must be gone.
if grep -RIn --include='*.yaml' 'namespace: zabisa-dt' deploy/kubernetes deploy/argocd >/tmp/zabisa-old-namespace.txt; then
  cat /tmp/zabisa-old-namespace.txt >&2
  echo '[hotfix] ERROR: stale namespace zabisa-dt remains in deployment manifests.' >&2
  exit 1
fi

if ! grep -q 'name: zabisa-app' deploy/kubernetes/base/platform.yaml; then
  echo '[hotfix] ERROR: namespace manifest zabisa-app not found.' >&2
  exit 1
fi

echo '[hotfix] running cluster-independent preflight...'
./scripts/preflight-offline.sh

# Kubernetes schema validation is deliberately opt-in because "$KUBECTL_BIN" client-side
# apply can still contact the configured API server for OpenAPI/discovery.
if [[ "${ZABISA_VALIDATE_CLUSTER:-0}" == "1" ]]; then
  if command -v "$KUBECTL_BIN" >/dev/null 2>&1; then
    echo '[hotfix] ZABISA_VALIDATE_CLUSTER=1: validating against configured Kubernetes API...'
    "$KUBECTL_BIN" apply --dry-run=server -f deploy/kubernetes/base >/dev/null
  else
    echo "[hotfix] ERROR: ZABISA_VALIDATE_CLUSTER=1 but kubectl executable is unavailable: $KUBECTL_BIN" >&2
    exit 1
  fi
else
  echo '[hotfix] Kubernetes API validation skipped (offline-safe default).'
  echo '[hotfix] When cluster access returns: ZABISA_VALIDATE_CLUSTER=1 bash scripts/apply-hotfix-0.1-0.2.sh'
fi

if command -v git >/dev/null 2>&1 && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  # If node_modules was ever accidentally committed, remove it from the index only;
  # keep the local dependency tree intact so developer workflow is not disrupted.
  if git ls-files --error-unmatch node_modules >/dev/null 2>&1 || git ls-files 'node_modules/**' | grep -q .; then
    echo '[hotfix] node_modules is tracked; removing it from the Git index (local files are kept)...'
    git rm -r --cached --ignore-unmatch node_modules >/dev/null
  fi

  changed_count="$(git status --short | wc -l | tr -d ' ')"
  deleted_count="$(git status --short | awk '$1 ~ /D/ || $2 ~ /D/ {n++} END {print n+0}')"
  untracked_count="$(git status --short | awk '$1 == "??" {n++} END {print n+0}')"
  printf '[hotfix] git changes: %s total, %s deletions, %s untracked\n' "$changed_count" "$deleted_count" "$untracked_count"
  echo '[hotfix] use: git status --short  (only if you need the full list)'
fi

echo '[hotfix] OK: Hotfix 0.1 repository hygiene + Hotfix 0.2 DT namespace/network baseline applied.'
echo '[hotfix] NOTE: Vault egress is intentionally not opened yet; add it with the Vault Injector hotfix using the existing cluster Vault endpoint/labels.'
