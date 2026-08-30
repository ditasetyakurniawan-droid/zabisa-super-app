# Zabisa Super App — Engineering Documentation Index

**Project lock:** Phase 3.7.6  
**Lock date:** 2026-08-31 (Asia/Jakarta)  
**Lock tag:** `phase-3.7.6-locked-2026-08-31`

This directory is the handoff source of truth for continuing Zabisa development.
Read `NEXT_SESSION_START_HERE.md` first when work resumes.

## Documentation map

| Document | Purpose |
|---|---|
| `PROJECT_STATE.md` | Current verified state and exact scope of the lock |
| `ARCHITECTURE.md` | Platform topology, service boundaries, data ownership |
| `BACKEND_SERVICES.md` | Backend services, responsibilities, key patterns |
| `BACKOFFICE.md` | Next.js Backoffice architecture, RBAC-aware UI, browser E2E |
| `MOBILE.md` | React Native architecture, physical-device workflow, deep links |
| `RBAC_SECURITY.md` | Roles, permissions, object authorization and security invariants |
| `AUDIT_OBSERVABILITY.md` | Append-only audit design, outbox delivery and correlation |
| `API_CONTRACTS.md` | Strict JSON/DTO rules and contract lessons |
| `LOCAL_DEVELOPMENT.md` | Ports, Docker, Android/ADB, Metro and local runtime |
| `TESTING_QUALITY.md` | Quality gates, current coverage and regression commands |
| `DEMO_DATA.md` | Development data policy and seeded functional scenarios |
| `PHASE_HISTORY.md` | Reconstructed engineering history through Phase 3.7.6 |
| `REQUIREMENTS_TRACEABILITY.md` | Requirement-to-implementation status matrix |
| `KNOWN_LIMITATIONS.md` | Items deliberately not claimed complete |
| `DEVELOPMENT_ROADMAP.md` | Structured next work plan |
| `NEXT_SESSION_START_HERE.md` | Exact restart checklist for the next engineering session |
| `PROJECT_LOCK.md` | Lock rules, branch/tag convention and handoff checklist |

## Rule

A feature is not considered DONE merely because a page or endpoint exists.
For critical flows, the expected path is:

`UI → BFF/Gateway → Service → DB transaction → audit/event/outbox → read-back → automated regression`.

Do not weaken strict API decoding, backend authorization, audit guarantees or
quality gates merely to make a test pass.
