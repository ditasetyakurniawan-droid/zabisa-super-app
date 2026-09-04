# Project State — Application Baseline and DT4.2.1 Checkpoint

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
browser. Delivery work has advanced through DT4.2.1 without declaring the
application deployed.

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

Not run:

- Jenkins branch indexing or pipeline build;
- application image build, vulnerability scan or Harbor push;
- worker/containerd image-pull proof;
- database backup/isolated restore drill or migration;
- application Deployment or ArgoCD sync.

The active next execution is the combined DT4.3/DT4.4 development delivery:
first prove Jenkins quality, private Sonar and digest-pinned Dockerized Trivy
with publication defaulted off, then use a separate parameterized build to
build, scan, push nine immutable images and render GitOps manifests. The parent
job returns to disabled afterward. This does not authorize migration or sync.

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
- sky-blue production-shaped UI baseline;
- standalone login outside bottom tabs;
- secure session storage;
- contextual deep-link parsing and native URL scheme configuration.

Physical-device UI was iteratively reviewed during development, but the mobile
screen-level automated coverage is still incomplete and is explicitly tracked
as future work.

## Lock principle

Phase 3.7.6 is a **development baseline lock**, and DT4.2.1 is an
**operational integration checkpoint**. Neither is a production launch
declaration.

Production push notification providers, production payment providers, iOS
release signing, final Sonar/CI/CD policy and production deployment remain
separate completion gates.
