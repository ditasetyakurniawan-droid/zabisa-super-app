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

# Phase 3.9 premium UI work is allowed to change presentation source, but only on
# an explicit UI/test allowlist. This replaces the old coverage-hotfix invariant
# that rejected every production UI change, while keeping API/state/business
# modules outside the permitted surface.
allowed_mobile_changes=(
  apps/mobile/src/app/App.tsx
  apps/mobile/src/assets/zabisa-quran-mascot.png
  apps/mobile/src/assets/zabisa-female-mascot.png
  apps/mobile/src/assets/zabisa-premium-mascot-duo.png
  apps/mobile/src/assets/zabisa-premium-hero.jpg
  apps/mobile/src/assets/zabisa-premium-hero-seamless.png
  apps/mobile/src/assets/zabisa-premium-soft-bg.jpg
  apps/mobile/src/components/UI.tsx
  apps/mobile/src/components/UI.coverage.test.tsx
  apps/mobile/src/components/Mascot.tsx
  apps/mobile/src/components/Motion.tsx
  apps/mobile/src/components/StartupLoading.tsx
  apps/mobile/src/components/PremiumUI.test.tsx
  apps/mobile/src/features/account/AccountScreen.tsx
  apps/mobile/src/features/auth/LoginScreen.tsx
  apps/mobile/src/features/content/ContentDetailScreen.tsx
  apps/mobile/src/features/content/ContentListScreen.tsx
  apps/mobile/src/features/donation/CampaignDetailScreen.tsx
  apps/mobile/src/features/donation/DonationCheckoutScreen.tsx
  apps/mobile/src/features/donation/DonationScreen.tsx
  apps/mobile/src/features/guardian/GuardianOverviewScreen.tsx
  apps/mobile/src/features/guardian/GuardianStudentScreen.tsx
  apps/mobile/src/features/home/HomeScreen.tsx
  apps/mobile/src/features/kajian/KajianScreen.tsx
  apps/mobile/src/features/notifications/NotificationsScreen.tsx
  apps/mobile/src/features/NawasenaScreens.test.tsx
  apps/mobile/src/navigation/RootNavigator.tsx
  apps/mobile/src/navigation/RootNavigator.coverage.test.tsx
  apps/mobile/src/theme/tokens.ts
)

is_allowed_mobile_change() {
  local candidate="$1"
  local allowed
  for allowed in "${allowed_mobile_changes[@]}"; do
    [[ "$candidate" == "$allowed" ]] && return 0
  done
  return 1
}

if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  while IFS= read -r changed; do
    [[ -n "$changed" ]] || continue
    is_allowed_mobile_change "$changed" || fail "Mobile change is outside the premium UI allowlist: $changed"
  done < <(git status --porcelain --untracked-files=all -- apps/mobile/src | awk '{print $2}')
fi

./scripts/verify-phase39-mobile-redesign.sh >/dev/null \
  || fail 'Phase 3.9 protected logic/navigation invariants no longer hold'

echo '[dt58-sonar-coverage] PASS: behavioural coverage remains present; Mobile changes are restricted to the reviewed premium UI allowlist and protected logic invariants still hold.'
