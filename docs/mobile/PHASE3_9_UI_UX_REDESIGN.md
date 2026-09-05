# Phase 3.9 — Mobile UI/UX Redesign

## Scope

Phase 3.9/3.9.1 is a pure UI/UX redesign. It changes visual tokens, component shape,
layout hierarchy, microcopy presentation, navigation styling and ambient
Islamic geometry. It does not change application logic, backend contracts,
state management, validation, authentication, transactions or user-flow order.

## Accepted direction

- The first Sakinah emerald direction was implemented and physically reviewed,
  then rejected because its four-column shortcuts and monochrome treatment felt
  rigid and dated. It is not the forward design baseline.
- Nawasena cobalt/navy/cyan/gold semantic tokens are the active direction.
- Original Quran learner mascot is bundled locally with no external dependency.
- Eight actions retain the same routes but now have distinct service identity.
- Shared animated Islamic ornament with reduced-motion fallback.
- 48dp minimum touch target and readable text hierarchy.
- Cool layered canvas, premium hero surface and restrained card elevation.
- Decorated contextual headers and detail headers.
- Floating five-item bottom navigation with unchanged destinations.
- Icon-led Kajian, Donation and Content lists.
- Updated Login and Home hierarchy while retaining every existing action.

## Zero-logic invariant

The redesign must not modify these logic-bearing modules:

- `src/api/**`;
- `src/store/**`;
- `src/types/**`;
- `src/utils/**`;
- donation idempotency;
- notification deep-link parsing;
- navigation parameter definitions.

Navigation styling may change, but destination names, tab order, deep-link
behavior and authentication guards remain unchanged.

## Automated exit gate

```bash
npm run mobile:quality
npm run admin:typecheck
npm run lint --workspace=@zabisa/admin-web -- --max-warnings=0
npm run admin:build
./scripts/preflight-offline.sh
```

## Physical-device and Backoffice gate

Before migration approval:

1. run `ZABISA_REBUILD=1 npm run mobile:device` on the connected Android phone;
2. verify Home, Login, password visibility, Guardian, Tahfidz, grades,
   attendance, reports, notifications, Kajian and Donation;
3. repeat essential screens with a larger system font and reduced motion;
4. run the local Backoffice and verify login plus critical navigation;
5. capture PASS evidence and confirm no raw errors, clipped content or broken
   buttons;
6. keep database migration and ArgoCD sync disabled until a separate explicit
   approval.
