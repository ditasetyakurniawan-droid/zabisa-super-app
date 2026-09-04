#!/bin/sh
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

mkdir -p coverage
report="coverage/npm-audit.json"

if ! npm audit --omit=dev --json > "$report"; then
  # npm exits non-zero when vulnerabilities exist; the policy parser below
  # distinguishes accepted advisories from transport or schema failures.
  :
fi

if [ ! -s "$report" ]; then
  echo '[npm-audit] ERROR: npm did not produce an audit report.' >&2
  exit 1
fi

node ./scripts/verify-npm-audit.mjs "$report"
