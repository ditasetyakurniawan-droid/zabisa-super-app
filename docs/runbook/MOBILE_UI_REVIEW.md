# Mobile UI Review Runbook

Before accepting a mobile UI increment:

1. `npm run mobile:quality`
2. `ZABISA_REBUILD=1 npm run mobile:device` only when native/theme files changed; otherwise `npm run mobile:device`.
3. Validate on a physical Android device: Home, login/password visibility, Guardian child list, Tahfidz, empty grade/attendance/report states, notifications, donation and kajian.
4. Confirm no raw backend errors, clipped text, broken icons, inaccessible controls or private data exposure.
5. Capture screenshots at normal font size and one larger system font size.
6. Update the relevant implementation document and ADR when design/architecture decisions change.

## Phase 3.9 zero-logic review

For the Nawasena redesign, inspect the changeset before acceptance:

```bash
git diff --name-only <baseline>...HEAD -- apps/mobile/src
```

Allowed paths are presentation modules under `theme/`, `components/`, screen
`.tsx` files and navigation visual configuration. Reject the changeset if it
modifies `api/`, `store/`, `types/`, `utils/`, donation idempotency,
notification deep-link parsing or navigation parameter definitions.

The migration gate remains closed until both physical-device UI review and the
local Backoffice critical navigation check pass.
