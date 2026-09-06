# Project State — DT58 Delivery Locked / DT5 Next

## Executive status

Zabisa currently has a production-shaped local platform composed of:

- React Native mobile application;
- Next.js Backoffice;
- Go API Gateway;
- Go bounded-context services;
- MySQL 8.4;
- NATS;
- MinIO;
- append-only cross-service audit delivery;
- backend-enforced RBAC and object-level guardian authorization.

Phase 3.7.6 remains the historical application restore point where the
Backoffice critical functional matrix was first verified through a real Chrome
browser. DT4.5.7 immutable delivery is complete, but application deployment is
not declared because migration and ArgoCD sync have not run.

The current immutable delivery lock supersedes the earlier DT4.5.7 image
checkpoint: application/image revision
`eee3284a6989857b6d4332f01d453763ccaf71b2`, Jenkins readiness `#18`, delivery
`#19`, and GitOps revision `4fbc8b5db597cbdf73199f8f927eb0ac2cc544c9`
all passed. The dedicated Zabisa Sonar gate requires 75% New Code coverage and
keeps the remaining quality conditions unchanged. Nine Harbor image digests
and 16 GitOps references are verified. Jenkins is DISABLED; Kubernetes,
migration and ArgoCD remain not run.

## Current DT deployment status

Verified:

- DT2 Vault/CA, ServiceAccounts, NetworkPolicies and runtime/migrator MySQL
  authentication;
- DT3 read-only inventory showing all seven target schemas empty;
- deterministic migration waves, zero retries, advisory locks and migration
  checksum/drift controls;
- immutable `linux/amd64` image source, pinned application base indexes,
  Trivy/SBOM attestations and post-push Harbor digest verification logic;
- existing Jenkins/Harbor delivery topology and credentials by identifier;
- `zabisa-super-app-v1` created from the existing
  `tropical-management-v1` Multibranch pattern with automatic triggers empty
  and the job disabled;
- support and regression tests for the actual Jenkins `GitHubSCMSource`
  configuration shape.
- private Sonar analysis, Quality Gate and digest-pinned Trivy readiness passed
  in Jenkins build `#6` with publication controls off;
- dedicated `zabisa-super-app-gitops` ownership, deterministic Kustomize render
  and credential-safe Jenkins publication are defined in source;
- the Trivy 0.74.0 readiness incompatibility is proven corrected live;
- Jenkins root-artifact handling and the legacy Sonar TypeScript analyzer
  compatibility gap are corrected by the DT4.5.1 source hotfix.
- all ten DT4.5.2 Sonar security hotspots are removed from source without
  marking findings safe or weakening the private Quality Gate;
- the admin Sonar project includes all intended 70 TypeScript source files.
- build `#9` proves zero remaining Security Hotspots; focused Admin and Mobile
  unit tests now provide LCOV evidence for the secured new code while retaining
  the 80% Quality Gate requirement.
- build `#10` proves the private Quality Gate passes with 96.2% new-code coverage
  and all nine immutable images build successfully; its first Trivy policy exit
  occurred before Harbor or GitOps publication;
- DT4.5.4 preserves complete scan/SBOM evidence on failure, evaluates all images,
  blocks fixable HIGH/CRITICAL findings and repairs a stale enabled Jenkins parent
  after an interrupted operator terminal.
- build `#11` archived 109 fixable HIGH/CRITICAL rows, reduced to three shared
  dependency/runtime sources; DT4.5.5 upgrades Go crypto, fixes Admin OpenSSL and
  removes unnecessary package-manager tooling from the Admin runtime image.
- build `#12` proves all nine remediated images build and scan successfully;
  Harbor authentication succeeds, while the old `zabisa` project path is denied;
- DT4.5.6 aligns all registry producers and consumers to the robot-authorized
  Harbor project `devops-apps` without renaming unrelated Zabisa identities.
- build `#13` confirms the entire build/scan chain and Harbor authentication are
  green, then exposes the required nested repository namespace and a
  first-column-only Docker digest parser;
- DT4.5.7 uses `devops-apps/zabisa/<image>` consistently and parses the validated
  digest at its actual position in Docker push output.
- Jenkins build `#14` passes the complete source/Sonar/Trivy/build/scan/push
  pipeline for application revision
  `e1af81dc96d5dc59876f090614e68dc48a32c59f`;
- nine Harbor digest references are verified and the evidence report SHA-256 is
  `9d5e3ef9c5f5fa3a58a9d565de1913a1d0fb21ed3df468658cfafc31b0d83d87`;
- GitOps commit `96cef84` validates 16 immutable references across 12 manifests,
  all bound to the same application revision;
- the Jenkins parent job returned to DISABLED;
- DT58 later passed GitHub, readiness `#18`, the dedicated 75% Sonar gate and
  delivery `#19` for `eee3284a6989857b6d4332f01d453763ccaf71b2`;
- GitOps `4fbc8b5db597cbdf73199f8f927eb0ac2cc544c9` supersedes the older render
  with 16 references across 12 manifests, and Jenkins is again DISABLED.

Not run:

- worker/containerd image-pull proof;
- database backup/isolated restore drill or migration;
- application Deployment or ArgoCD sync.

Phase 3.9.1 Mobile Nawasena UI/UX Redesign is complete at
`f1ba18854af2a2a965090af41eb8bfc40a637cb1`. Its 25 mobile tests, Guardian API
E2E, Backoffice source/runtime checks, GitHub gate and physical Android
installation/opening passed. Its source scope remained presentation-only.
Further UI development may resume later from this checkpoint.

DT5–DT8 is ready for controlled execution. This readiness adds an encrypted
backup/isolated-restore gate, content-only migration canary, exact-revision
manual ArgoCD sync, one-time secure SUPER_ADMIN bootstrap and internal
Backoffice/Android acceptance. It is not evidence that migration or sync has
already run.

## Verified at lock

### Backoffice

The real Chrome matrix covers twelve critical scenarios:

1. repeated navigation across all SUPER_ADMIN modules, including repeated
   `User & Access` navigation;
2. Data Santri create and update;
3. Guardian onboarding UI and staged relationship flow;
4. Tahfidz target create and edit;
5. Donation payment-method create and deactivate;
6. Notification compose;
7. Content Management create and update;
8. Kajian create and update;
9. Attendance upsert;
10. Academic Subject create and deactivate;
11. User & Access create and deactivate;
12. Audit Log cross-service provenance.

All twelve passed at the project lock.

### Backend/API

Verified:

- strict JSON decoding;
- student create/update contract;
- Tahfidz target POST/PATCH split;
- payment-method create/update DTO split;
- narrow guardian/notification candidate APIs;
- service-side RBAC;
- guardian object authorization;
- guardian relationship request → approve → revoke → re-request;
- stale-token rejection after role changes;
- self-demotion protection;
- manual donation verification;
- publish workflows for academic data;
- content/kajian public read-back;
- cross-service append-only audit delivery.

### Mobile

Verified quality/runtime foundation:

- TypeScript;
- ESLint;
- Jest;
- Guardian API E2E;
- populated development data across Tahfidz, grades, attendance, reports and
  notifications;
- Android physical-device deployment workflow;
- Phase 3.9.1 Nawasena cobalt/navy/cyan/gold UI review candidate with an
  original Quran learner mascot and colour-coded service actions;
- standalone login outside bottom tabs;
- secure session storage;
- contextual deep-link parsing and native URL scheme configuration.

The first Phase 3.9 Sakinah presentation was physically reviewed and rejected
as too rigid and visually dated. Nawasena supersedes it without changing logic.
Screen-level automated coverage is still incomplete and is explicitly tracked
as future work.

## Lock principle

Phase 3.7.6 is a **historical development baseline**, DT4.2.1 is an
**operational integration checkpoint**, and the DT58 revision is the current
**immutable delivery lock**. None is a production launch declaration.

Production push notification providers, production payment providers, iOS
release signing, final Sonar/CI/CD policy and production deployment remain
separate completion gates.
