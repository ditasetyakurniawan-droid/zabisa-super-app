# Phase 3.1 — Mobile UX Hardening

## Completed by this patch
- Migrated semantic design tokens from green to an original sky-blue Zabisa visual system.
- Redesigned Home header, hero, quick actions, content cards and campaign presentation.
- Refined login/profile UI while preserving secure password visibility controls.
- Refined Guardian overview and student detail hierarchy.
- Added Indonesian date, currency, tahfidz and attendance presentation utilities with regression tests.
- Refined Kajian, Donation and Notification visual hierarchy.
- Removed `adb pm clear` from normal device workflow because some OEM firmware blocks the permission.
- Added Android navigation/status-bar theme integration. Native theme changes require one ARM64 rebuild.
- Added `npm run mobile:quality` quality-gate command.

## Explicitly not claimed complete
- Grades, attendance and reports have healthy API endpoints but current local E2E data may be empty. UI is validated for empty states; populated-state acceptance still requires real development seed records.
- Production FCM/APNs and production payment gateway completion still depend on real credentials/infrastructure.
- Test coverage must grow through meaningful auth/navigation/critical-flow tests before final SonarQube acceptance.
