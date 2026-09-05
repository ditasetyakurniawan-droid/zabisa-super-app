# Phase 3.9 — Mobile UI/UX Redesign

## Scope

Phase 3.9 is a pure UI/UX redesign. It changes visual tokens, component shape,
layout hierarchy, microcopy presentation, navigation styling and ambient
Islamic geometry. It does not change application logic, backend contracts,
state management, validation, authentication, transactions or user-flow order.

## Implemented presentation

- Sakinah emerald/ivory/gold semantic tokens.
- Shared animated Islamic ornament with reduced-motion fallback.
- Consistent button family and 48dp minimum touch target.
- Warm layered canvas, arch feature surfaces and restrained card elevation.
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
