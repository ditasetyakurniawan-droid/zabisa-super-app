#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if ! command -v git >/dev/null 2>&1 || ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo '[secret-hygiene] SKIP: Git worktree is required for tracked-file scanning.'
  exit 0
fi

prohibited_files="$(
  git ls-files \
    | grep -E '(^|/)(\.env|id_rsa|id_ed25519)$|\.(pem|p12|pfx|jks)$' \
    | grep -vE '(^|/)\.env\.example$|debug\.keystore$' \
    || true
)"
if [[ -n "$prohibited_files" ]]; then
  printf '%s\n' "$prohibited_files" >&2
  echo '[secret-hygiene] ERROR: prohibited secret/private-key files are tracked.' >&2
  exit 1
fi

readonly SECRET_PATTERN='-----BEGIN (RSA |EC |OPENSSH |)?PRIVATE KEY-----|AKIA[0-9A-Z]{16}|github_pat_[A-Za-z0-9_]{20,}|gh[pousr]_[A-Za-z0-9]{20,}|xox[baprs]-[A-Za-z0-9-]{10,}|AIza[0-9A-Za-z_-]{35}'
secret_hits="$(mktemp -t zabisa-secret-hygiene.XXXXXX)"
trap 'rm -f "$secret_hits"' EXIT

if git grep -I -n -E -- "$SECRET_PATTERN" -- ':!*.md' ':!*.example' ':!package-lock.json' > "$secret_hits" 2>/dev/null; then
  cat "$secret_hits" >&2
  echo '[secret-hygiene] ERROR: probable credential material detected in tracked source.' >&2
  exit 1
fi

echo '[secret-hygiene] PASS: tracked source contains no recognized credential material.'
