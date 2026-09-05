#!/usr/bin/env bash

set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

fail() {
  echo "[phase39-mobile] ERROR: $*" >&2
  exit 1
}

sha256sum -c docs/mobile/PHASE3_9_LOGIC_BASELINE.sha256 >/dev/null \
  || fail 'a protected mobile logic/dependency file changed'

grep -Fq "primary: '#087A68'" apps/mobile/src/theme/tokens.ts \
  || fail 'Sakinah primary token missing'
grep -Fq 'minimumTapSize: 48' apps/mobile/src/theme/tokens.ts \
  || fail '48dp accessibility target missing'
grep -Fq 'AccessibilityInfo.isReduceMotionEnabled()' apps/mobile/src/components/UI.tsx \
  || fail 'reduced-motion handling missing'
grep -Fq 'Animated.loop' apps/mobile/src/components/UI.tsx \
  || fail 'ambient Islamic motion missing'
grep -Fq 'export function IslamicOrnament' apps/mobile/src/components/UI.tsx \
  || fail 'shared Islamic ornament missing'
grep -Fq 'backgroundColor: colors.primary' apps/mobile/src/components/UI.tsx \
  || fail 'shared primary button styling missing'

tab_count="$(grep -c '<Tab.Screen' apps/mobile/src/navigation/RootNavigator.tsx)"
stack_count="$(grep -c '<Stack.Screen' apps/mobile/src/navigation/RootNavigator.tsx)"
[[ "$tab_count" == '5' ]] || fail "expected 5 unchanged tabs, found $tab_count"
[[ "$stack_count" == '9' ]] || fail "expected 9 unchanged stack destinations, found $stack_count"

for tab in Home Kajian Donasi Notifikasi Akun; do
  grep -Fq "name=\"$tab\"" apps/mobile/src/navigation/RootNavigator.tsx \
    || fail "navigation destination missing: $tab"
done

for doc in \
  docs/mobile/DESIGN_SYSTEM.md \
  docs/mobile/PHASE3_9_UI_UX_REDESIGN.md \
  docs/architecture/ADR-011-MOBILE-SAKINAH-DESIGN-SYSTEM.md; do
  [[ -s "$doc" ]] || fail "required redesign document missing: $doc"
done

echo '[phase39-mobile] PASS: Sakinah presentation is present and protected mobile logic is unchanged.'
