# Project Lock — 2026-08-31

> Historical application restore point. The active deployment checkpoint is
> DT58 Sonar 75% immutable delivery COMPLETE and is recorded in
> `deployment/CURRENT-STATE-AND-ROADMAP.md`. Do not interpret this older tag as
> the current `main` deployment state.

## Current immutable delivery lock

The current runtime lock is:

- application/image revision:
  `eee3284a6989857b6d4332f01d453763ccaf71b2`;
- GitOps revision: `4fbc8b5db597cbdf73199f8f927eb0ac2cc544c9`;
- Jenkins readiness `#18` and delivery `#19`: SUCCESS;
- recommended immutable tag:
  `dt58-sonar75-delivery-locked-2026-09-06`.

See `deployment/DT58-SONAR75-DELIVERY-LOCK.md`. This lock covers image delivery
and GitOps publication only. Migration, Kubernetes apply and ArgoCD sync remain
not run.

Historical DT4.2.1 checkpoint tag:

`dt4.2.1-jenkins-integration-locked-2026-09-04`

This tag locks the earlier source/documentation state after the existing
Jenkins job was created disabled. The later DT4.5.7 delivery used application
revision `e1af81dc96d5dc59876f090614e68dc48a32c59f` and GitOps commit `96cef84`;
both are historical because the DT58 lock above now supersedes them. No
checkpoint authorizes migration or ArgoCD sync.

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
