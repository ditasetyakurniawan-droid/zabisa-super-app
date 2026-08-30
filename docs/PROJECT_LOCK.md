# Project Lock — 2026-08-31

## Lock point

Phase:

`3.7.6 — Attendance Accessibility Contract / Functional Contract Audit`

Git tag to use:

`phase-3.7.6-locked-2026-08-31`

## Why this point is locked

The current baseline has passed:

- strict API contract regression;
- RBAC regression;
- extended audit coverage;
- populated mobile/demo regression;
- Backoffice standalone runtime/session regression;
- 12/12 real Chrome functional tests.

This makes it a suitable restore point before the next major scope expansion.

## Lock rules

Until development resumes:

- no ad-hoc edits;
- no dependency force-upgrades;
- no migration rewrites;
- no force-push;
- no deletion of historical migration files;
- preserve the tag.

## Restore reference

A future engineer should be able to:

```bash
git checkout phase-3.7.6-locked-2026-08-31
```

to inspect this exact engineering checkpoint.

## Git workflow after lock

Future work should branch from the locked baseline, preferably:

```text
main
  └─ feature/phase-3.8-ci
```

Use PRs once GitHub CI is established.
