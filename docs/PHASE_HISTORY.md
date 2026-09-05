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

## DT3.1-DT3.3 — Controlled migration readiness

Status: **SOURCE GATES ACTIVE / DATABASE NOT MUTATED**

Verified date: `2026-09-04`

DT3.1 committed deterministic PreSync waves, disabled automated ArgoCD sync,
set migration Jobs to zero automatic retries and added a sequential read-only
schema inventory (`cee801f`; CI run `33865841795` passed).

DT3.2 executed only that read-only inventory. All seven Zabisa databases
reported zero tables and zero migration records, and every temporary Pod was
removed. Evidence SHA-256:
`951809641f4c094f7abc8a800a6e7b26e97c78f6ce49e3acf82449429957e8b5`.

DT3.3 hardens the shared migration engine with a per-database advisory lock,
exact SQL checksums, fail-closed legacy handling and tests covering all eighteen
current migration files' reviewed statement shapes. It also expands the
backup/restore evidence contract.

No migration, application Deployment or ArgoCD sync is authorized by these
source changes. Immutable migration images and tested recovery evidence remain
mandatory before a separately approved `content` canary.

## DT4.0-DT4.1 — Immutable image readiness and source controls

Status: **SOURCE HARDENING / IMAGE PUSH NOT RUN**

Discovery date: `2026-09-04`

Source baseline `4783fa6` and its Engineering Quality Gate passed. Read-only
DT4 discovery from the operator workstation proved Docker/buildx readiness and
a homogeneous `linux/amd64` cluster. It also found unpinned application base
images, missing local Trivy, untrusted local Harbor CA, no namespace
imagePullSecret, and no post-push digest evidence in the existing build script.
Local tool/trust findings are not treated as Jenkins facts; DT4.2 must verify
them on `jenkins-dt`, while worker/containerd trust is checked separately.

DT4.1 pins the three reviewed OCI base-image indexes and makes the build path
fail closed on a dirty source tree, platform drift, missing scan/SBOM evidence,
local image replacement after scanning, and local/Harbor digest disagreement.
Jenkins retains scan artifacts and the final Harbor digest report.

No `docker login`, build, pull, push, Kubernetes mutation, database migration,
application Deployment or ArgoCD sync is part of DT4.1.

## DT4.2 — Existing Jenkins and Harbor alignment

Status: **PASS / JOB CREATED DISABLED / BUILD NOT RUN**

Discovery date: `2026-09-04`

Live discovery proved that Jenkins is an existing Docker Compose service on
`192.168.100.57`. The successful `tropical-management-v1` Multibranch job uses
`github-credentials-id`, private Sonar, `harbor-cred`, Docker build/push and a
GitOps update stage. Zabisa adopts this existing delivery path rather than
creating another runner, registry or deployment channel.

GitHub Actions remains the source-quality and Browser E2E gate. Jenkins retains
its local tests/coverage for private Sonar, then owns image build, pinned Trivy
scan, SBOM, Harbor push and GitOps render. The Dockerized Trivy runner reuses the
existing Docker socket and is pinned to Trivy `0.74.0` by OCI index digest.

Harbor is operational through the shared daemon-level insecure-registry
compatibility configuration already used by existing projects. Zabisa neither
broadens nor embeds that exception: pipeline source still rejects per-command
TLS bypass flags. Strict hostname-TLS remediation remains shared platform
hardening outside this application rollout.

The job bootstrap clones the proven Tropical Multibranch configuration, changes
only the SCM identity/repository/script path, and creates
`zabisa-super-app-v1` with automatic triggers cleared and the job disabled.
Creation does not authorize indexing, a build,
Harbor login/push, GitOps update, migration, deployment or ArgoCD sync.

DT4.2.1 updates the renderer after the first authenticated plan proved the
existing Tropical job uses the GitHub Branch Source XML shape
(`repoOwner`/`repository`) rather than a plain Git SCM `remote`. The first run
stopped before `createItem`, so Jenkins and Harbor were not mutated. Regression
tests now cover both supported Multibranch SCM shapes before another apply.

The corrected apply authenticated as the existing Jenkins administrator,
rendered `scm_type=github`, cleared automatic triggers, created
`zabisa-super-app-v1` disabled and read the stored configuration back
successfully. Render evidence SHA-256:
`508e439fc18a3958d4f9ff1c2852997e409a0a79dc623c6ddaa5f86981a013de`.

DT4.2/DT4.2.1 is now closed as an integration checkpoint. No branch indexing,
pipeline build, Docker/Harbor operation, GitOps publication, Kubernetes change,
database migration, application Deployment or ArgoCD sync occurred. DT4.3 must
add default-off delivery parameters before the first controlled Jenkins run.
The repository checkpoint tag is
`dt4.2.1-jenkins-integration-locked-2026-09-04`.

## DT4.3-DT4.4 — Controlled Jenkins development delivery

Status: **SOURCE READY / LIVE EXECUTION PENDING**

DT4.3 adds three explicit Jenkins parameters—image build, Harbor push and
GitOps render—with all defaults set to off and dependency checks between them.
The first indexed build proves repository quality, private Sonar and the pinned
Dockerized Trivy vulnerability database without publishing images.

For development speed, the same operator session may then run DT4.4 with all
three controls explicitly enabled. It builds and scans nine immutable
`linux/amd64` images, records SBOM/scan attestations, pushes them through the
existing `harbor-cred`, verifies remote digests, renders sixteen GitOps image
references and returns the Jenkins parent job to disabled. Migration, workload
deployment and ArgoCD sync remain outside this phase.

## DT4.5 — Dedicated GitOps publication source ready

- Confirmed the existing Docker Compose Jenkins and Harbor delivery ownership.
- Recorded the successful private Sonar analysis and Quality Gate.
- Fixed the Trivy 0.74.0 CLI incompatibility that blocked readiness.
- Added Sonar-only TypeScript configs so the private analyzer does not skip the
  Backoffice and mobile sources that intentionally use bundler resolution.
- Restricted Jenkins discovery to `main` and added safe reconciliation for the
  existing disabled job.
- Added deterministic Kustomize render, source provenance, GitOps commit/push,
  remote verification and exact post-build image/workspace cleanup.
- Pointed the manual ArgoCD Application at
  `zabisa-super-app-gitops/apps/zabisa/overlays/dt`.

Images, migrations, application workloads and ArgoCD sync remain not run at
this source checkpoint.

## DT4.5.1 — Jenkins artifact and Sonar compatibility hotfix

Readiness build `#6` passed source quality, private Sonar Quality Gate and
digest-pinned Trivy 0.74.0 database readiness with every publication control
off. Delivery build `#7` stopped before the first Docker build because
Jenkins-created `.gitsha` and `report-task.txt` files made the source worktree
dirty. The immutable-image gate rejected the build as designed; Harbor and
GitOps publication were not reached.

The same log showed that both Sonar-only TypeScript configs still inherited
application configs using `moduleResolution=bundler`; the legacy analyzer
rejected the inherited value before applying the override and skipped all 70
TypeScript files. DT4.5.1 moves Jenkins control metadata below ignored
`build/`, makes the Sonar configs standalone and adds a verified resume path
that reuses readiness evidence while running one new complete delivery build.

## DT4.5.2 — Sonar hotspot closure

Removed the ten source-level security hotspots reported by Jenkins build `#8`:
eight Docker wildcard copies, one weak donation identifier generator and one
hard-coded clear-text Backoffice backend default. Expanded the Sonar TypeScript
set to 70/70 files and added an offline regression verifier. The blocking
Quality Gate remains unchanged.

## DT4.5.3 — Sonar new-code coverage

Build `#9` confirmed zero remaining security hotspots, then exposed the next
blocking condition: new-code coverage was 0% against the unchanged 80% gate.
Added focused Admin and Mobile unit tests, executed all workspace test suites
in CI/Jenkins, and imported both LCOV reports into Sonar.
