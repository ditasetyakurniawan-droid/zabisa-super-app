#!/usr/bin/env bash
set -Eeuo pipefail

fail() {
  echo "[dt58-sonar-coverage] ERROR: $*" >&2
  exit 1
}

tests=(
  apps/mobile/src/components/UI.coverage.test.tsx
  apps/mobile/src/features/home/HomeScreen.test.tsx
  apps/mobile/src/features/NawasenaScreens.test.tsx
  apps/mobile/src/navigation/RootNavigator.coverage.test.tsx
)

for test_file in "${tests[@]}"; do
  [[ -s "$test_file" ]] || fail "missing behavioural test: $test_file"
done

grep -Fq "'src/**/*.{ts,tsx}'" apps/mobile/jest.config.js ||
  fail 'Mobile Jest no longer collects production TypeScript coverage'
grep -Fq '**/*.test.tsx' apps/mobile/jest.config.js ||
  fail 'Mobile Jest no longer discovers TSX behavioural tests'
grep -Fq 'apps/mobile/coverage/lcov.info' sonar-project.properties ||
  fail 'Sonar no longer imports Mobile LCOV'

grep -Fq "describe('Nawasena shared UI'" "${tests[0]}" ||
  fail 'shared UI behaviour matrix is incomplete'
grep -Fq "describe('Nawasena HomeScreen'" "${tests[1]}" ||
  fail 'Home behaviour matrix is incomplete'
grep -Fq "describe('Nawasena service screens'" "${tests[2]}" ||
  fail 'service-screen behaviour matrix is incomplete'
grep -Fq "describe('Nawasena root navigation presentation'" "${tests[3]}" ||
  fail 'navigation behaviour matrix is incomplete'

grep -Fq "jest.mock('react-native-safe-area-context'" "${tests[0]}" ||
  fail 'shared UI coverage test does not provide deterministic Safe Area context'
grep -Fq "typeof node.props.onPress === 'function'" "${tests[1]}" ||
  fail 'Home interactions do not select callable Pressable nodes safely'
if grep -Fq 'parent!.props.onPress' "${tests[1]}"; then
  fail 'Home test still relies on an unstable renderer parent'
fi
grep -Fq 'async function renderHome' "${tests[1]}" ||
  fail 'Home renderer does not await asynchronous React effects'
grep -Fq 'async function render(element' "${tests[2]}" ||
  fail 'service-screen renderer does not await asynchronous React effects'

if git diff --name-only HEAD -- \
  apps/mobile/src/components/UI.tsx \
  apps/mobile/src/components/AppIcon.tsx \
  apps/mobile/src/features/home/HomeScreen.tsx \
  apps/mobile/src/features/donation \
  apps/mobile/src/features/kajian \
  apps/mobile/src/navigation/RootNavigator.tsx \
  apps/mobile/src/theme/tokens.ts | grep -q .; then
  fail 'production Mobile source changed in the coverage-only hotfix worktree'
fi

echo '[dt58-sonar-coverage] PASS: deterministic behavioural tests cover Nawasena UI, Home, services and navigation without production-source or Sonar-exclusion changes.'
