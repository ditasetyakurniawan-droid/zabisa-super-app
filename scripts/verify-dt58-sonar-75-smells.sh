#!/usr/bin/env bash
set -Eeuo pipefail

fail() {
  echo "[dt58-sonar-75] ERROR: $*" >&2
  exit 1
}

coverage_line="$(grep '^sonar.coverage.exclusions=' sonar-project.properties)"
for required in \
  '**/*_test.go' \
  '**/__mocks__/**' \
  '**/generated/**' \
  '**/*.d.ts' \
  'apps/mobile/src/types/**' \
  'apps/mobile/src/config/runtime.ts' \
  'apps/mobile/src/App.tsx' \
  'apps/mobile/src/app/App.tsx'; do
  [[ "$coverage_line" == *"$required"* ]] || fail "missing narrow coverage exclusion: $required"
done

for protected_scope in \
  'services/**' \
  'packages/go/**' \
  'apps/admin-web/app/**' \
  'apps/mobile/src/features/**'; do
  [[ "$coverage_line" != *"$protected_scope"* ]] || fail "business scope must remain covered: $protected_scope"
done

if grep -RInE --include='*.ts' --include='*.tsx' '\bFormEvent\b' apps/admin-web; then
  fail "deprecated React FormEvent remains"
fi
if grep -RInE --include='*.ts' --include='*.tsx' \
     'parent!\.props\.onPress|students\.data!\[|roleLabels\[row\.role as' apps || \
   grep -nE 'return body\.data as T' apps/mobile/src/api/client.ts; then
  fail "reviewed unnecessary assertion remains"
fi
if grep -RInE --include='*.ts' --include='*.tsx' \
     'key=\{`\$\{item\.date\}-\$\{index\}`\}' apps/mobile/src; then
  fail "array-index attendance key remains"
fi

grep -Fq 'target="${SONAR_NEW_COVERAGE_TARGET:-75}"' scripts/configure-sonar-quality-gate.sh \
  || fail "75% Sonar target is missing"
grep -Fq 'Zabisa Platform - New Code 75' scripts/configure-sonar-quality-gate.sh \
  || fail "dedicated project Quality Gate is missing"
grep -Fq 'api/qualitygates/copy' scripts/configure-sonar-quality-gate.sh \
  || fail "shared/default Quality Gate protection is missing"
grep -Fq 'A non-coverage Quality Gate condition changed unexpectedly' scripts/configure-sonar-quality-gate.sh \
  || fail "non-coverage gate preservation check is missing"
bash -n scripts/configure-sonar-quality-gate.sh

echo '[dt58-sonar-75] PASS: 75% gate control, narrow exclusions and reviewed smell cleanup are present.'
