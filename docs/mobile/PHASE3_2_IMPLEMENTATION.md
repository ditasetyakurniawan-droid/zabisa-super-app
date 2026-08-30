# Phase 3.2 - Mobile Product Polish, Populated Guardian Validation, and Deep Links

## Why this phase exists

Physical-device review of Phase 3.1 confirmed that the sky-blue direction is materially better and the core Guardian flow works. The review also identified remaining product-level gaps:

- login was still rendered inside the main bottom tabs;
- Android system navigation contrast could visually clash with the app;
- Guardian empty-state validation did not prove populated grades, attendance, and reports;
- notification cards did not mark items read;
- legacy deep links did not contain the student object context;
- automated development notes were too technical for UI review;
- test coverage needed to move from plumbing tests toward auth and navigation behavior.

## Implemented

- Standalone root-stack login screen. Main tabs are no longer the auth container.
- Sky-blue navigation polish and compact bottom-tab active state.
- Additional safe-area bottom padding for scroll content.
- Development-only seeded grade, attendance, and published report using real APIs.
- Populated Guardian E2E mode that fails when required UI data is empty.
- Notification read/read-all integration.
- Backward-compatible `zabisa://` deep-link parser.
- New deep-link contract includes `student_id` in Tahfidz/Academic links.
- Android and iOS URL-scheme registration for `zabisa://`.
- Guardian notes/statuses localized for Indonesian UI.
- Auth-store and deep-link regression tests.

## Definition of done for this phase

This phase is not complete merely because screens render. The following must pass:

```bash
npm run mobile:quality
npm run mobile:seed:guardian
npm run mobile:e2e:guardian:populated
```

After native URL-scheme/theme changes, one Android ARM64 rebuild is required:

```bash
ZABISA_REBUILD=1 npm run mobile:device
```

## Development data rule

`scripts/mobile-seed-guardian.sh` refuses non-localhost targets. Seeded records are fictitious development records and must never be used as production data.


## React Native 0.87 FlatList compatibility

`FlatList.ListHeaderComponent` is intentionally given `undefined` when
there is no header. React Native 0.87 generated typings do not accept
`null` for this property.

This is a source-level compatibility fix and does not change the
notification business flow.


## Development seed RBAC

Development seed actors intentionally follow backend authorization boundaries:

- teacher actor: subject and grade development data;
- admin actor: administrative attendance and report lifecycle operations;
- guardian actor: read-side verification.

The seed remains localhost-only.

A missing report-publish endpoint or authorization failure is considered a
failed seed. HTTP 404 must never be treated as successful publication.
