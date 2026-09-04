# Zabisa Development and DT Delivery Roadmap

## Active delivery track

| Phase | Status | Outcome or target |
|---|---|---|
| DT2 | PASS | Vault/CA/network identities and in-cluster DB authentication verified |
| DT3 | PASS / migration not run | Empty-schema inventory and controlled migration engine ready |
| DT4.1 | PASS / source only | Immutable image, SBOM, scan and digest-proof source controls ready |
| DT4.2.1 | PASS / locked | Existing Jenkins Multibranch job created disabled; no indexing/build |
| DT4.3 | NEXT | Quality, private Sonar and Dockerized Trivy readiness only |
| DT4.4 | BLOCKED | Controlled image build, scan, SBOM and Harbor publication |
| DT5 | BLOCKED | Backup and isolated restore evidence |
| DT6 | BLOCKED | Sequential database migration with explicit approval |
| DT7 | BLOCKED | Reviewed GitOps render and controlled ArgoCD sync |
| DT8 | BLOCKED | Service, ingress, observability and rollback acceptance |

The DT track follows `deployment/CURRENT-STATE-AND-ROADMAP.md` and
`runbook/JENKINS_DELIVERY.md`. Product phases below remain valid development
backlog and do not authorize deployment mutations.

## Priority 0 — Resume discipline

Before adding features:

1. pull the locked Git tag/branch;
2. read `NEXT_SESSION_START_HERE.md`;
3. run baseline smoke;
4. do not redesign architecture before establishing a failing requirement.

## Phase 3.8 — GitHub CI and quality gate

Status: **PASS / operational**

Goal: make the repository's local quality discipline reproducible in GitHub.

Deliverables:

- GitHub Actions workflow for Go tests;
- Backoffice TypeScript/lint/build;
- Browser E2E using service containers/Compose strategy;
- Mobile TypeScript/lint/Jest;
- SonarQube/SonarCloud integration as appropriate;
- dependency vulnerability review;
- secret scanning;
- artifact retention for Playwright traces/screenshots;
- branch protection policy.

Exit gate:

`PR cannot merge when a required engineering gate is red.`

Implementation result:

- CI workflow, scoped Go reports, mobile coverage import, dependency checks,
  secret hygiene, optional SonarQube integration, Dependabot, and isolated
  Backoffice browser E2E are implemented in source;
- Engineering Quality Gate and Backoffice Browser E2E have passed repeatedly on
  the real repository. GitHub remains the remote source gate, while private
  Sonar and delivery stay on the existing Jenkins infrastructure.

## Phase 3.9 — Mobile test and UX completion

Goal: raise confidence in the end-user application.

Work:

- test API client/session refresh;
- navigation/deep-link integration tests;
- Home/Content/Kajian/Donation/Guardian/Notification screen tests;
- loading/empty/error/offline/maintenance/session-expired states;
- accessibility checks;
- physical Android critical E2E;
- deep-link physical-device verification;
- increase meaningful coverage, prioritizing critical flows rather than an
  arbitrary percentage.

## Phase 4.0 — Production notification integration

- FCM;
- APNs;
- token lifecycle;
- delivery receipts/failures;
- retry/dead-letter policy;
- notification preferences;
- provider metrics;
- staging validation.

## Phase 4.1 — Production payment integration

- choose provider;
- signed webhook verification;
- idempotency;
- payment-state machine;
- reconciliation;
- timeout/expiry;
- refund/cancellation policy if required;
- audit;
- staging sandbox E2E.

## Phase 4.2 — Observability and reliability

- OpenTelemetry traces;
- structured logs;
- metrics;
- dashboard;
- service SLOs;
- alert policy;
- outbox lag monitoring;
- NATS health;
- database pool metrics;
- trace correlation from Backoffice/mobile through services.

## Phase 4.3 — Security hardening

- production secrets management;
- JWT/key rotation;
- refresh-token/session policy review;
- rate limits;
- CSP/security headers;
- dependency/SBOM/container scan;
- backup encryption;
- least privilege for deployment/database accounts;
- penetration/security test plan.

## Phase 4.4 — Storage/media

- finalize MinIO/S3 object lifecycle;
- signed upload/read strategy;
- file validation;
- image optimization;
- quota/lifecycle/backup.

## Phase 4.5 — Staging and production deployment

- immutable versioned images;
- managed domain/TLS;
- reverse proxy/load balancer;
- readiness/liveness;
- rolling/blue-green rollout;
- migration procedure;
- rollback procedure;
- staging seed strategy;
- production data policy.

## Phase 4.6 — iOS release track

On macOS/Xcode:

- dependency/native build validation;
- URL scheme/deep link;
- signing/provisioning;
- APNs;
- release archive;
- TestFlight.

## Phase 4.7 — Operational readiness

- backup/restore drill;
- disaster recovery;
- admin SOP;
- incident response;
- audit retention policy;
- privacy/data retention;
- production acceptance test;
- release checklist.

## Recommended next-session first task

Start with **DT4.3 controlled Jenkins readiness**. Keep
`zabisa-super-app-v1` disabled until the Jenkinsfile defaults image build,
Harbor push and GitOps publication to off. The first approved run proves only
quality, private Sonar and Dockerized Trivy readiness.
