#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

fail() {
  printf '[quality-verify] ERROR: %s\n' "$*" >&2
  exit 1
}

for required in \
  .github/workflows/ci.yml \
  .github/dependabot.yml \
  scripts/go-quality.sh \
  scripts/npm-audit-gate.sh \
  scripts/quality-gate.sh \
  scripts/verify-npm-audit.mjs \
  scripts/verify-secret-hygiene.sh \
  sonar-project.properties; do
  [[ -f "$required" ]] || fail "missing $required"
done

for executable in \
  scripts/go-quality.sh \
  scripts/npm-audit-gate.sh \
  scripts/quality-gate.sh \
  scripts/verify-quality-gate.sh \
  scripts/verify-secret-hygiene.sh; do
  [[ -x "$executable" ]] || fail "$executable must be executable"
done

if grep -En 'go (test|vet)[[:space:]]+\./\.\.\.' Makefile Jenkinsfile scripts/*.sh; then
  fail 'unscoped Go test/vet would traverse unrelated node_modules packages'
fi

grep -Fq 'sonar.go.tests.reportPaths=coverage/go-test-report.json' sonar-project.properties \
  || fail 'Sonar Go test report path is not configured'
grep -Fq 'sonar.javascript.lcov.reportPaths=apps/mobile/coverage/lcov.info' sonar-project.properties \
  || fail 'Sonar mobile LCOV path is not configured'
grep -Fq '**/*_test.go' sonar-project.properties \
  || fail 'Sonar source exclusions must prevent duplicate test indexing'
grep -Fq '"audit:production": "./scripts/npm-audit-gate.sh"' package.json \
  || fail 'policy-aware production dependency audit command is missing'
grep -Fq 'GHSA-W3RX-R6R6-PGPR' scripts/verify-npm-audit.mjs \
  || fail 'time-bounded image-size advisory policy is missing'

if grep -RInE --include='*.ts' --include='*.tsx' \
  'navigation:[[:space:]]*any|route:[[:space:]]*any|api<any' apps/mobile/src; then
  fail 'untyped mobile navigation or API response remains'
fi

echo '[quality-verify] PASS: CI, Sonar, scoped Go, and mobile typing invariants.'
