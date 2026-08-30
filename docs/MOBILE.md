# Mobile Application

## Stack

- React Native 0.87.0
- React 19.2.3
- TypeScript
- React Navigation
- TanStack Query
- Zustand
- secure native keychain/keystore session storage
- Jest + React Native Testing Library

Package:

`id.or.subulussalam.zabisa`

## Source organization

Feature-first structure is the required direction:

```text
src/
  app/
  navigation/
  features/
    auth/
    home/
    content/
    kajian/
    donation/
    guardian/
    student/
    tahfidz/
    academic/
    attendance/
    notifications/
  components/
  api/
  hooks/
  store/
  theme/
  utils/
```

Avoid returning to a gigantic `App.tsx` or oversized screens.

## UI baseline

Current design uses a sky-blue high-trust application palette. It is an
independent Zabisa design and must not copy another financial application's
trade dress or assets.

Implemented UI foundations include:

- design tokens;
- reusable cards/buttons/headers;
- loading/empty/error states;
- secure password field;
- standalone root Login screen;
- Guardian overview/student views;
- Content/Kajian/Donation/Notification flows;
- bottom-tab polish and safe-area handling.

## Authentication/navigation

Login is outside the main bottom-tab navigation.

Private deep links can defer until authentication and then resume navigation.

Supported canonical deep-link patterns include contextual Guardian paths such
as:

```text
zabisa://guardian/students/{student_id}/tahfidz/{entry_id}
zabisa://guardian/students/{student_id}/academic/{grade_id}
```

Native URL scheme `zabisa` is configured for Android and iOS source.

## Physical Android development

Primary verified device workflow used a physical OPPO device.

Important local rules:

- Zabisa Metro runs on host port **8082**;
- device port `8081` is reversed to host `8082`;
- device `8088` is reversed to host API Gateway `8088`;
- do not kill the unrelated host service already using port 8081;
- do not use `adb shell pm clear id.or.subulussalam.zabisa` on this OPPO;
  the OEM blocks it with `CLEAR_APP_USER_DATA` SecurityException;
- for a clean state use in-app logout or Android Settings manually.

Typical reverse mappings:

```text
device:8081 → host:8082
device:8088 → host:8088
```

## Android toolchain baseline

- Android Studio under `/opt/android-studio`
- SDK under `$HOME/Android/Sdk`
- NDK 27.1.12297006
- Java 21
- local debug optimized for ARM64 physical-device development
- release remains multi-ABI/AAB oriented

Gradle was intentionally tuned for the development laptop's memory limits.

## Quality

Use:

```bash
npm run mobile:quality
```

The lock run verifies TypeScript, ESLint, Jest/coverage and Guardian API E2E.

Current mobile coverage is still low overall and many screen components remain
at 0% unit coverage. This is a next-phase priority; do not present the current
coverage as production-complete.

## Current Guardian functional data

Development/demo flows exercise:

- multiple linked students;
- Tahfidz;
- grades;
- attendance;
- reports;
- donation history;
- notifications.

## Pending mobile work

- materially increase screen/API-client/navigation test coverage;
- automate physical-device critical-flow E2E;
- complete offline/retry/maintenance/session-expired state testing;
- validate deep links on physical Android after final navigation changes;
- validate iOS build/signing on macOS/Xcode;
- integrate production FCM/APNs credentials;
- production release hardening.
