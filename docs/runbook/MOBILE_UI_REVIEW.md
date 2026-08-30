# Mobile UI Review Runbook

Before accepting a mobile UI increment:

1. `npm run mobile:quality`
2. `ZABISA_REBUILD=1 npm run mobile:device` only when native/theme files changed; otherwise `npm run mobile:device`.
3. Validate on a physical Android device: Home, login/password visibility, Guardian child list, Tahfidz, empty grade/attendance/report states, notifications, donation and kajian.
4. Confirm no raw backend errors, clipped text, broken icons, inaccessible controls or private data exposure.
5. Capture screenshots at normal font size and one larger system font size.
6. Update the relevant implementation document and ADR when design/architecture decisions change.
