# Engineering Phase History

This is a reconstructed implementation history based on the current repository
and the verified development session. Very early bootstrap work is summarized
as baseline rather than claiming exact command-by-command chronology.

## Foundation / early backend

Established:

- monorepo;
- Go API Gateway and bounded services;
- MySQL service-owned databases;
- Docker Compose;
- NATS;
- MinIO;
- admin development identities;
- initial end-to-end backend flows.

Early backend Guardian E2E validated linked Student → Tahfidz → outbox →
Notification.

## Phase 3 — Mobile production-shaped foundation

Introduced:

- React Native feature-first structure;
- reusable design tokens/components;
- secure native session storage;
- Guardian screens;
- API error normalization;
- deep-link parsing;
- Android physical-device workflow;
- TypeScript/ESLint/Jest quality gates.

Native monorepo fixes included React/Metro singleton resolution and ARM64 local
build optimization.

## Phase 3.1 — Mobile sky-blue UI

Improved:

- visual hierarchy;
- Home;
- Guardian;
- Kajian;
- Donation;
- Notifications;
- tab layout;
- Indonesian formatting;
- safe device workflow.

## Phase 3.2 — Mobile navigation/deep-link polish

Added:

- standalone Login outside bottom tabs;
- session-aware Account behavior;
- contextual Guardian deep links;
- Android/iOS URL scheme configuration;
- development-data population scripts;
- populated Guardian E2E gate.

## Phase 3.3 — Broad demo population

Populated real API development data so Public/Guardian features visibly operate
rather than appearing empty.

## Phase 3.4 — Backoffice RBAC

Added/hardened:

- Backoffice role separation;
- backend permission enforcement;
- stale-session/token rejection after role changes;
- self-demotion protection;
- CMS integration;
- audit of role changes.

## Phase 3.4.1 — Query hardening

Moved Backoffice server state toward typed TanStack Query and corrected source
quality invariants.

## Phase 3.4.2 — Next standalone runtime

Corrected production-shaped Next runtime:

- generated standalone server;
- non-root container;
- healthcheck;
- authenticated repeated protected-route smoke.

This resolved a runtime configuration mismatch involving `next start`.

## Phase 3.5 — Operational Backoffice

Implemented/verified operational flows for:

- Students;
- Guardian linking;
- Attendance;
- Tahfidz targets;
- Academic Subjects/Grades/Reports;
- Content/Kajian;
- Donation/payment methods/campaign lifecycle;
- Notifications.

Object-level Guardian authorization was hardened.

## Phase 3.5.x — Operational fixes

Important fixes:

- source invariant became intent-aware rather than banning every useEffect;
- exact Donation campaign PATCH route registration;
- demo campaign-update verifier no longer assumed first campaign ordering;
- Guardian onboarding create/link/approve/revoke/re-request flow;
- duplicate-email handling.

## Phase 3.6 — Browser E2E and audit hardening

Added:

- Playwright;
- system Chrome execution;
- cross-service append-only audit;
- audit correlation;
- browser navigation regression for prior User & Access issue.

Playwright video was disabled because trace/screenshot were sufficient and
video unnecessarily required a managed ffmpeg binary.

## Phase 3.7 — Principal functional contract audit

This phase audited mismatches between UI payloads and strict backend DTOs.

Major corrections:

- Student DTO/form contract;
- Tahfidz target create/update split;
- Payment Method create/update split;
- least-privilege candidate APIs;
- read/write UI permission separation;
- local secure-cookie configuration;
- BFF trace/request propagation;
- expanded sensitive mutation audit coverage.

### Phase 3.7.1

Fixed Donation JWT claim helper integration compile error.

### Phase 3.7.2

Fixed sidebar accessible names and made Playwright tests independent.

### Phase 3.7.3

Fixed async React form lifetime bug caused by using
`event.currentTarget` after `await`. Expanded browser matrix to 12 workflows.

### Phase 3.7.4

Fixed audit verifier `ARG_MAX` failure by streaming large audit JSON via stdin.

### Phase 3.7.5

Aligned Kajian operational slug visibility and Attendance E2E selector scope.

### Phase 3.7.6 — Current lock

Fixed Attendance accessible label semantics and dependency state.

Final state:

- 12/12 real Chrome Backoffice functional tests pass;
- strict API contracts pass;
- RBAC passes;
- extended append-only audit passes;
- populated mobile/demo regression passes;
- Backoffice runtime/session regression passes.

This is the locked development baseline for the next session.

## Hotfix 0.3.7 — API Gateway readiness contract

Corrected the API Gateway health contract so the source now serves the
`/health/ready` path already configured in its Kubernetes readiness probe.
Added a Go regression test and an offline preflight invariant to prevent future
source/manifest drift. This hotfix does not change MySQL, migrations, Vault,
RBAC, mobile contracts, or bounded-service behavior.

## Phase 3.8 — Reproducible CI and code-quality foundation

Introduced GitHub pull-request gates, Dependabot, scoped Go coverage/test
reports, mobile LCOV import, dependency and secret checks, optional SonarQube
analysis, and isolated Backoffice browser E2E. Jenkins now consumes the same
scoped report contract.

Readability work split the API Gateway bootstrap, routing, access control, and
HTTP handler into focused files. Route matching now requires an exact path
boundary, with regression tests. Mobile screen navigation and API result DTOs
are typed instead of relying on explicit `any`.

Validation added a fail-closed npm audit policy with exact, expiring exceptions
for the two unpatched `image-size` advisories inherited through React Native
Metro. New high/critical advisories remain blocking and the raw JSON report is
retained as CI evidence.

The offline preflight distinguishes tracked source JSON from generated reports
and validates `go test -json` output as NDJSON, matching Sonar's Go test report
contract.

Phase 3.8 remains open until the workflow passes in GitHub and both jobs become
required branch-protection checks.

## DT deployment track 1 - MySQL and Vault provisioning source

Replaced the initial operator scaffold with a fail-closed provisioning contract
for seven MySQL databases, fourteen least-privilege identities per bounded
client source, mandatory TLS, and the exact Vault KV v2 paths consumed by
runtime and migration manifests.

The workflow rejects wildcard MySQL hosts, avoids credentials in process
arguments, reuses existing Vault passwords on rerun, supports explicit rotation,
and verifies the complete database/account/privilege/Vault matrix without
printing secret values. This records source readiness only; live provisioning
remains pending until the plan gate and Phase 3.8 remote CI both pass.

After the DT topology inspection, account scope was aligned with the existing
Calico behavior. DB-dt is external to Kubernetes but lies inside the current
`192.168.0.0/16` Calico pool, so MySQL observes pod source IPs rather than only
worker-node IPs. The provisioner now accepts canonical IPv4 network scopes,
normalizes `/16` to MySQL netmask notation, rejects broader or wildcard scopes,
and retains the narrower per-workload Kubernetes egress policy.

Docker Compose now mounts only `00-databases.sql`; the DT account template can
no longer be auto-executed with unresolved placeholders during local/E2E MySQL
initialization. This is source alignment only and does not mutate MySQL, Vault,
Calico, or the Kubernetes cluster.
### DT1 MySQL operator-client compatibility hardening

- Added a digest-pinned Oracle MySQL 8.4 Docker client runner for operator
  workstations where `/usr/bin/mysql` is MariaDB.
- Provisioning and live verification now accept `MYSQL_CLIENT_BIN` and fail
  closed when the selected client lacks `--ssl-mode=VERIFY_CA`.
- Local MySQL readiness now requires an authenticated TCP query, preventing the
  initialization-only server from being reported healthy.
- Follow-up recovery hardened the Docker client with standard-input forwarding;
  without it, piped SQL could be discarded while non-mutating `-e` checks still
  succeeded. The live verifier detected the empty schema set before any
  migration or deployment was allowed.

## DT deployment track 2 — Vault identity and in-cluster credential proof

DT1 provisioning and both live boundary verifiers completed successfully. A
one-off workstation credential test was rejected because MySQL correctly saw a
NAT source address outside the bounded Calico account network; that rejection
did not roll back or invalidate DT1.

DT2 adds an idempotent bootstrap for the existing Vault/Kubernetes integration,
CA-only trust Secrets and shared runtime keys. A temporary runtime/migrator
canary proves the actual Vault passwords against MySQL from pods selected by the
existing Vault and MySQL NetworkPolicies. It never widens MySQL account hosts,
creates duplicate platform infrastructure, prints credentials, runs migrations
or triggers ArgoCD sync.

DT2.1 removes a canary startup race: the runner now waits for the explicit
authentication result and fails early on a non-zero container exit. Pod Ready
is no longer accepted as proof because it can precede the application's first
log line when the image is already cached on a worker.

<!-- DT2_CLOSURE_START -->
## DT2.1-DT2.2 — Credential canary stabilization and runtime closure

Status: **PASS**

Verified date: `2026-09-04`

Verified source commit: `838c71d`

- DT2.1 fixed the canary runner to wait for authentication results.
- DT2.2 verified live Vault/CA/ServiceAccount/NetworkPolicy/role consistency.
- Runtime and migrator credentials authenticated to MySQL from allowed cluster pods.
- Temporary canary pods were removed.
- Database migration, application deployment, image publication, and ArgoCD sync were not run.

Next: **DT3 migration readiness audit (read-only)**.

See [`CURRENT-STATE-AND-ROADMAP.md`](deployment/CURRENT-STATE-AND-ROADMAP.md).
<!-- DT2_CLOSURE_END -->
