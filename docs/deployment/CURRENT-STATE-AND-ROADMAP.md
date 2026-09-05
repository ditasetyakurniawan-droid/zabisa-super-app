# Zabisa Current State and Delivery Roadmap

> Official checkpoint: **DT4.5.7 COMPLETE / PHASE 3.9 DEVELOPMENT ACTIVE**
>
> Live job: `zabisa-super-app-v1` — `DISABLED`, no automatic trigger
>
> Lock tag: `dt4.2.1-jenkins-integration-locked-2026-09-04`
>
> Updated on: `2026-09-05`

This is the operational starting point for developers and operators. It records
what is proven, what has not run, and which approval gate currently controls
delivery.

## Current state

| Area | Status | Evidence |
|---|---|---|
| Repository and CI | PASS | DT4.2.1 SCM renderer source and Engineering Quality Gate succeeded |
| Kubernetes compatibility | PASS | kubectl `1.30.14`; server `1.30` |
| Vault and network boundary | PASS | Injector, roles, CA, default-deny and explicit DNS/Vault/MySQL egress verified |
| MySQL abstraction | PASS | `db-dt` -> `192.168.100.70:3306` |
| Runtime/migrator DB authentication | PASS | Both identities authenticated from allowed in-cluster canaries |
| Seven target schemas | EMPTY / VERIFIED | DT3.2 read-only inventory: 0 tables and 0 migration rows in every database |
| Temporary canaries | PASS | Removed after DT2 and DT3.2 verification |
| Migration source controls | PASS | Sequential waves, zero retry, advisory lock and checksums committed |
| Immutable deployment images | PASS / PUBLISHED | Jenkins #14 built, scanned and pushed nine source-SHA images; nine Harbor digests verified |
| Existing Jenkins/Harbor path | PASS / LOCKED | Compose Jenkins uses Docker socket, `harbor-cred`, private Sonar and existing Harbor compatibility mode |
| Zabisa Jenkins job | PASS / DISABLED | Remote job was reconciled main-only and trigger-free; controlled runner returned it to disabled |
| Private Sonar | PASS | Build #14 analysis and blocking Quality Gate passed with complete TypeScript scope |
| Image scanning | PASS | All nine images passed the fixable HIGH/CRITICAL policy and produced SBOM/scan evidence |
| GitOps repository | PASS / PUBLISHED | Commit `96cef84` validates source `e1af81dc...`, 16 image references and 12 manifests |
| Cluster Harbor pull | UNPROVEN | No namespace Docker config Secret or ServiceAccount imagePullSecret found |
| Backup and isolated restore proof | NOT PROVEN | Mandatory before any database mutation |
| Database migration | NOT RUN | Blocked by image, backup/restore and operator approval gates |
| Application deployment | NOT DEPLOYED | Blocked until migration and render gates pass |
| ArgoCD sync | NOT RUN | Automated sync disabled; explicit operator approval required |

## Delivery scope

Runtime services are `api-gateway`, `identity`, `content`, `student`, `tahfidz`,
`academic`, `donation`, and `notification`. The seven stateful services have
separate DB-only migrator identities. `api-gateway` is DB-free.

## Completed foundation

- CI, tests, secret hygiene, browser E2E, YAML, shell and Compose gates pass.
- Runtime deployments use `APP_MODE=serve` and cannot auto-run migrations.
- Migration Jobs use identities separate from runtime identities.
- Production MySQL requires TLS with a pinned CA.
- Vault Agent uses per-workload ServiceAccounts and audience-bound tokens.
- DT2 proved runtime and migrator authentication from inside the cluster.
- DT3.1 disabled automatic ArgoCD sync, assigned deterministic migration waves,
  set `backoffLimit: 0`, and added a read-only inventory runner.
- DT3.2 proved all seven target databases are empty and removed every temporary
  inventory Pod.

## Active roadmap

### DT3.3 — Migration engine source hardening

Status: **PASS / `4783fa6`**

Targets:

- serialize each schema with a MySQL advisory lock;
- persist SHA-256 per applied migration and reject historical drift;
- fail closed on legacy unchecksummed rows;
- test all eighteen migration files for approved statement shapes and reject
  multi-statement `ALTER` files;
- record the DT3.2 live evidence and remaining gates.

Exit gate passed: source and remote CI succeeded. No database or cluster
mutation occurred.

### DT4.1 — Immutable image source hardening

Status: **PASS / `df2d275` / SOURCE ONLY**

Pin the three reviewed base-image indexes, lock the platform to `linux/amd64`,
bind scan/SBOM attestations to each local image ID and verify Harbor digests
after push. Source and remote CI must pass before any image build/push approval.

### DT4.2-DT4.2.1 — Existing Jenkins integration

Status: **PASS / CHECKPOINT LOCKED**

Use the proven `tropical-management-v1` Multibranch pattern on the existing
Compose Jenkins host. GitHub remains the source/browser gate; Jenkins retains
private Sonar, image build, Dockerized Trivy, SBOM, Harbor push and GitOps
render. The existing `github-credentials-id`, `harbor-cred`, `sonar-dt`, Docker
socket and Harbor compatibility mode are reused. The Zabisa job is created
disabled with no automatic trigger. Authentication, rendered
`GitHubSCMSource`, repository, SCM credential identifier and script path were
read back and verified. No indexing, build or push ran.

### DT4.3-DT4.5.7 — Controlled immutable delivery

Status: **COMPLETE**

Readiness build `#6` remains the verified default-off checkpoint. Delivery
build `#14` passed all quality, Sonar, Trivy, image build/scan/SBOM, Harbor push,
digest verification and GitOps publication stages for source
`e1af81dc96d5dc59876f090614e68dc48a32c59f`. All images use
`harbor-dt.co.id/devops-apps/zabisa/<image>:<source-sha>`. GitOps commit
`96cef84` validates 16 immutable references across 12 manifests. The parent
Jenkins job is disabled and automatic triggers remain absent.

### Phase 3.9 — Mobile UI/UX redesign and runtime acceptance

Status: **SOURCE IMPLEMENTATION ACTIVE / DEVICE PROOF PENDING**

Redesign presentation only through shared tokens, UI primitives, screen layout
and navigation styling. Do not change API/state/authentication/validation or
business behavior. Automated mobile and Backoffice gates run before a physical
Android test. Database migration remains blocked until both mobile-device and
Backoffice runtime acceptance are recorded.

### DT5 — Backup and isolated restore readiness

Status: **BLOCKED / EVIDENCE REQUIRED**

Produce a current encrypted full backup, capture checksum and binlog position,
restore it to an isolated target, and record validation and restore duration.
This phase prepares a recovery point; it does not authorize migration.

### DT6 — Controlled migration

Status: **BLOCKED BY DT5, PHASE 3.9 ACCEPTANCE AND OPERATOR APPROVAL**

Render and review exactly one `content` canary Job. Run it only after explicit
approval, verify completion and schema/checksum state, then stop. Remaining Jobs
run sequentially and stop at the first failure.

### DT7 — GitOps render and controlled sync

Status: **BLOCKED**

Render all runtime references with reviewed immutable digests, inspect the full
GitOps diff and sync only after explicit operator approval.

### DT8 — Service acceptance

Status: **BLOCKED**

Acceptance requires stable Ready pods, Vault injection, probes, internal service
discovery, API Gateway routing, ingress, observability, smoke/E2E tests, resource
behavior and a tested rollback procedure.

## Operator-control rules

1. Every phase begins with a read-only plan/render and ends with recorded evidence.
2. No phase advances without explicit approval from Dita.
3. Credentials, tokens, private keys and private CA material never enter Git.
4. Runtime and migration identities remain separate.
5. Application Deployments never run migrations automatically.
6. Production images are immutable and never use `latest`.
7. Cluster changes must match a reviewed Git changeset.
8. Temporary diagnostic resources must be labeled and removed.
9. Failure does not authorize rollback, rotation, rerun or sync.
10. kubectl must remain within supported minor skew of the server.
11. A database mutation requires both a tested recovery point and a separate
    explicit confirmation for the exact target.

## Developer starting point

```bash
git switch main
git pull --ff-only origin main
git status --short --branch
./scripts/verify-dt3-source.sh
./scripts/preflight-offline.sh
```

Read this file, `docs/PHASE_HISTORY.md`, and the active phase runbook before
changing deployment source.

Allowed now: development, tests, documentation, offline image/render planning
and source hardening.

Not allowed without later gates: migration, credential rotation, DT2 re-apply,
workload deployment, ArgoCD sync, broad NetworkPolicy access or mutable image
tags.

## Current handoff

```text
DT2.2: PASS
DT3.1 source controls: PASS at cee801f
DT3.2 live read-only inventory: PASS; all seven databases empty
DT3.3 migration engine hardening: PASS at 4783fa6
DT4.1 immutable image source hardening: PASS at df2d275
DT4.2 existing Jenkins pattern: PASS
DT4.2.1 Zabisa Multibranch bootstrap: PASS; job created disabled
Jenkins Sonar and Quality Gate: PASS
DT4.3 Dockerized Trivy readiness: PASS in build #6
DT4.4-DT4.5.7 immutable delivery: PASS in Jenkins build #14
Application image revision: e1af81dc96d5dc59876f090614e68dc48a32c59f
Harbor: 9 image tags and digests verified at devops-apps/zabisa
GitOps: PASS at 96cef84; 16 image references / 12 manifests
Jenkins parent: DISABLED
Physical Android redesign acceptance: PENDING
Backoffice post-redesign acceptance: PENDING
Cluster image pull: NOT PROVEN
Migration: NOT RUN
Application: NOT DEPLOYED
ArgoCD sync: NOT RUN
```
