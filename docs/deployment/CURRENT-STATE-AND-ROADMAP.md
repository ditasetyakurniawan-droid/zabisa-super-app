# Zabisa Current State and Delivery Roadmap

> Official checkpoint: **DT3.3 PASS / DT4.1 SOURCE HARDENING**
>
> Source baseline: `4783fa6`
>
> Verified on: `2026-09-04`

This is the operational starting point for developers and operators. It records
what is proven, what has not run, and which approval gate currently controls
delivery.

## Current state

| Area | Status | Evidence |
|---|---|---|
| Repository and CI | PASS | `4783fa6`; Engineering Quality Gate run `33869446657` succeeded |
| Kubernetes compatibility | PASS | kubectl `1.30.14`; server `1.30` |
| Vault and network boundary | PASS | Injector, roles, CA, default-deny and explicit DNS/Vault/MySQL egress verified |
| MySQL abstraction | PASS | `db-dt` -> `192.168.100.70:3306` |
| Runtime/migrator DB authentication | PASS | Both identities authenticated from allowed in-cluster canaries |
| Seven target schemas | EMPTY / VERIFIED | DT3.2 read-only inventory: 0 tables and 0 migration rows in every database |
| Temporary canaries | PASS | Removed after DT2 and DT3.2 verification |
| Migration source controls | PASS | Sequential waves, zero retry, advisory lock and checksums committed |
| Immutable deployment images | SOURCE HARDENING | Base digests and Harbor digest evidence controls under review; images not built |
| Harbor workstation trust | BLOCKED | `harbor-dt.co.id` resolves, but the issuing CA is not trusted locally |
| Image scanning | BLOCKED | Trivy is not installed on the build workstation |
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

Status: **ACTIVE / SOURCE ONLY**

Pin the three reviewed base-image indexes, lock the platform to `linux/amd64`,
bind scan/SBOM attestations to each local image ID and verify Harbor digests
after push. Source and remote CI must pass before any image build/push approval.

### DT4.2 — Trusted build, scan and Harbor publication

Status: **BLOCKED BY CA TRUST, TRIVY AND PULL CONTRACT**

Build, scan and push all nine images from one clean approved commit. Record
immutable Harbor digests and prove cluster image pull. Migration cannot run from
unresolved `REPLACE_SHA` references.

### DT5 — Backup and isolated restore readiness

Status: **BLOCKED / EVIDENCE REQUIRED**

Produce a current encrypted full backup, capture checksum and binlog position,
restore it to an isolated target, and record validation and restore duration.
This phase prepares a recovery point; it does not authorize migration.

### DT6 — Controlled migration

Status: **BLOCKED BY DT4, DT5 AND OPERATOR APPROVAL**

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
DT4.1 immutable image source hardening: ACTIVE
Harbor TLS trust / Trivy / cluster pull: BLOCKED OR UNPROVEN
Migration: NOT RUN
Application: NOT DEPLOYED
ArgoCD sync: NOT RUN
```
