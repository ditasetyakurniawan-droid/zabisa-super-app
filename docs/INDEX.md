# Zabisa Super App — Engineering Documentation Index

**Historical application lock:** Phase 3.7.6

**Current deployment checkpoint:** DT4.5.7 COMPLETE — immutable Harbor/GitOps delivery

**Current development checkpoint:** Phase 3.9.1 — mobile Nawasena UI/UX redesign

**Deployment lock tag:** `dt4.2.1-jenkins-integration-locked-2026-09-04`

**Updated date:** 2026-09-05 (Asia/Jakarta)

This directory is the handoff source of truth for continuing Zabisa development.
Read `NEXT_SESSION_START_HERE.md` first when work resumes.

## Documentation map

| Document | Purpose |
|---|---|
| `PROJECT_STATE.md` | Current verified application and deployment state |
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
| `deployment/CURRENT-STATE-AND-ROADMAP.md` | Authoritative DT rollout checkpoint and approval gates |
| `deployment/PHASE-DT4-IMMUTABLE-IMAGES.md` | Active immutable-image phase and remaining live proofs |
| `deployment/PHASE-DT45-GITOPS-SEPARATION.md` | Dedicated GitOps ownership, publication and execution boundary |
| `deployment/PHASE-DT451-JENKINS-ARTIFACT-HOTFIX.md` | Build #6/#7 evidence, repository-cleanliness correction and controlled resume |
| `deployment/PHASE-DT452-SONAR-HOTSPOT-CLOSURE.md` | Build #8 Quality Gate evidence and complete ten-hotspot source closure |
| `deployment/PHASE-DT453-NEW-CODE-COVERAGE.md` | Build #9 evidence and real unit coverage for secured new code |
| `deployment/PHASE-DT454-TRIVY-DELIVERY-RESUME.md` | Build #10 evidence, all-image Trivy policy and interrupted-terminal recovery |
| `deployment/PHASE-DT455-TRIVY-CVE-REMEDIATION.md` | Build #11 evidence and remediation of all three shared CVE sources |
| `deployment/PHASE-DT456-HARBOR-PROJECT-ALIGNMENT.md` | Build #12 evidence and authorized devops-apps registry path alignment |
| `deployment/PHASE-DT457-HARBOR-REPOSITORY-HIERARCHY.md` | Build #13 evidence, nested Zabisa repositories and robust push-digest parsing |
| `mobile/PHASE3_9_UI_UX_REDESIGN.md` | UI-only redesign scope, zero-logic invariant and device acceptance gate |
| `architecture/ADR-011-MOBILE-SAKINAH-DESIGN-SYSTEM.md` | Amended Nawasena design-system decision and migration safety boundary |
| `runbook/JENKINS_DELIVERY.md` | Existing Jenkins/Harbor workflow, controls and developer procedure |

## Rule

A feature is not considered DONE merely because a page or endpoint exists.
For critical flows, the expected path is:

`UI → BFF/Gateway → Service → DB transaction → audit/event/outbox → read-back → automated regression`.

Do not weaken strict API decoding, backend authorization, audit guarantees or
quality gates merely to make a test pass.

The Phase 3.7.6 tag remains a historical restore point. It does not supersede
the current DT rollout state recorded in `deployment/CURRENT-STATE-AND-ROADMAP.md`.
