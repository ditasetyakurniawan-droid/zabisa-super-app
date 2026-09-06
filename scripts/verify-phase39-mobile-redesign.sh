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

grep -Fq "primary: '#1769E0'" apps/mobile/src/theme/tokens.ts \
  || fail 'Nawasena primary token missing'
grep -Fq 'export const serviceColors' apps/mobile/src/theme/tokens.ts \
  || fail 'distinct service colour tokens missing'
grep -Fq 'minimumTapSize: 48' apps/mobile/src/theme/tokens.ts \
  || fail '48dp accessibility target missing'
grep -Fq 'AccessibilityInfo.isReduceMotionEnabled()' apps/mobile/src/components/UI.tsx \
  || fail 'reduced-motion handling missing'
grep -Fq 'Animated.loop' apps/mobile/src/components/UI.tsx \
  || fail 'ambient Islamic motion missing'
grep -Fq 'export function IslamicOrnament' apps/mobile/src/components/UI.tsx \
  || fail 'shared Islamic ornament missing'
grep -Fq '<Mascot variant="learning"' apps/mobile/src/features/home/HomeScreen.tsx \
  || fail 'reusable Quran learner mascot missing from Home'
grep -Fq "require('../assets/zabisa-quran-mascot.png')" apps/mobile/src/components/Mascot.tsx \
  || fail 'original Quran learner mascot is not wired through shared Mascot component'
[[ -s apps/mobile/src/assets/zabisa-quran-mascot.png ]] \
  || fail 'mascot asset missing'
grep -Fq 'backgroundColor: colors.primary' apps/mobile/src/components/UI.tsx \
  || fail 'shared primary button styling missing'

grep -Fq 'export function MascotDuo' apps/mobile/src/components/Mascot.tsx \
  || fail 'shared male/female mascot duo missing'
grep -Fq "require('../assets/zabisa-premium-hero-seamless.png')" apps/mobile/src/components/StartupLoading.tsx \
  || fail 'startup loading seamless premium hero image missing'
[[ -s apps/mobile/src/assets/zabisa-premium-hero-seamless.png ]] \
  || fail 'seamless premium startup hero asset missing'
grep -Fq 'resizeMode="contain"' apps/mobile/src/components/StartupLoading.tsx \
  || fail 'startup hero must use contain mode to prevent clipping'
grep -Fq "require('../assets/zabisa-premium-soft-bg.jpg')" apps/mobile/src/components/StartupLoading.tsx \
  || fail 'startup loading soft premium background missing'
[[ -s apps/mobile/src/assets/zabisa-premium-soft-bg.jpg ]] \
  || fail 'soft premium background asset missing'
grep -Fq 'Belajar Al-Qur’an, tumbuh dalam adab.' apps/mobile/src/components/StartupLoading.tsx \
  || fail 'premium startup tagline missing'
grep -Fq 'Sebaik-baik kalian adalah yang belajar Al-Qur’an dan mengajarkannya.' apps/mobile/src/components/StartupLoading.tsx \
  || fail 'startup hadith copy missing'
! grep -Eq 'Kajian publik|Donasi amanah|Portal wali|Kajian, donasi, dan ruang belajar Islami' apps/mobile/src/components/StartupLoading.tsx \
  || fail 'legacy public pills/copy returned to startup loading'
[[ -s apps/mobile/src/assets/zabisa-female-mascot.png ]] \
  || fail 'female mascot asset missing'

mascot_screens=(
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
  apps/mobile/src/features/kajian/KajianDetailScreen.tsx
  apps/mobile/src/features/kajian/KajianScreen.tsx
  apps/mobile/src/features/notifications/NotificationsScreen.tsx
)
for screen in "${mascot_screens[@]}"; do
  grep -Eq '<(AppHeader|DetailHeader|Mascot)([[:space:]>])' "$screen" \
    || fail "contextual mascot presentation missing from $screen"
done

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

echo '[phase39-mobile] PASS: Nawasena presentation is present and protected mobile logic is unchanged.'
