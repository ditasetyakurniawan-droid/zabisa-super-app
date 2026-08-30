# Development and Demo Data

## Purpose

Development data exists to make every major surface visibly functional and to
exercise vertical slices through real APIs.

It is not production data.

## Populated areas

Current development/demo fixtures cover:

- public Kajian;
- News;
- Programs;
- Profiles;
- Gallery metadata;
- donation campaigns;
- payment methods;
- campaign updates;
- multiple Guardian-linked students;
- Tahfidz;
- grades;
- attendance;
- reports;
- donation history;
- notifications.

## Rules

- Seed through service APIs, not direct cross-service DB writes.
- Development-only scripts should refuse unsafe/non-local targets where
  appropriate.
- Tests should deactivate/archive temporary fixtures when practical.
- Do not build production behavior that depends on hard-coded demo UUIDs.
- UI may normalize obvious development-test notes so demos remain readable,
  but must not hide real production errors.

## Useful commands

```bash
npm run demo:refresh
npm run demo:verify
```

If these commands evolve, update this document and the next-session handoff.
