# Phase 3.3 Full Development Demo Data


## Jest TypeScript compatibility

Mobile tests import `describe`, `it`, and `expect` explicitly from
`@jest/globals`.

This keeps `tsc --noEmit` deterministic in the npm-workspaces monorepo and
avoids relying on ambient Jest globals.
