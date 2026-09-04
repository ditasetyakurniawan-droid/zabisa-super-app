# Zabisa Current State and Delivery Roadmap

> Official checkpoint: **DT2.2 PASS**
>
> Verified source commit: `838c71d`
>
> Verified on: `2026-09-04`

This document is the operational starting point for developers and operators.
It records what is proven, what is not yet executed, and which approval gate is active.

## Current state

| Area | Status | Evidence |
|---|---|---|
| Repository and CI | PASS | `main`/`origin/main` at `838c71d`; Engineering Quality Gate succeeded |
| Kubernetes compatibility | PASS | kubectl `1.30.14`; server `1.30` |
| Vault | PASS | Active, unsealed, Injector/webhook/service verified |
| MySQL abstraction | PASS | `db-dt` -> `192.168.100.70:3306` |
| CA and network boundary | PASS | Vault CA, MySQL CA, default-deny, DNS/Vault/MySQL egress verified |
| Runtime identities | PASS | 8 Vault runtime roles consistent |
| Migrator identities | PASS | 7 Vault migrator roles consistent |
| Runtime DB authentication | PASS | Authenticated from an allowed in-cluster canary |
| Migrator DB authentication | PASS | Authenticated from an allowed in-cluster canary |
| Temporary canaries | PASS | Removed after verification |
| Database migration | NOT RUN | Blocked until DT3 audit and approval |
| Application deployment | NOT DEPLOYED | Blocked until migration/image gates pass |
| ArgoCD sync | NOT RUN | Requires explicit operator approval |

## Delivery scope

Runtime services: `api-gateway`, `identity`, `content`, `student`, `tahfidz`,
`academic`, `donation`, and `notification`.

The seven stateful services have separate migrator identities. `api-gateway`
is DB-free and has no migration identity.

## Completed foundation

- Source, test, Sonar, browser E2E, secret hygiene, YAML, shell, and Compose gates pass.
- Production image design uses immutable commit-SHA tags and prohibits `latest`.
- Runtime deployments use `APP_MODE=serve` and cannot auto-run migrations.
- Migration Jobs use DB-only identities separate from runtime identities.
- External MySQL access requires TLS with a pinned CA.
- Vault Agent uses per-workload ServiceAccounts and audience-bound tokens.
- DT2.1 fixed canary result polling; DT2.2 proved runtime and migrator login in-cluster.

## Active roadmap

### DT3 — Migration readiness audit

Status: **NEXT / READ-ONLY**

Targets:

- inventory every migration and target schema;
- define the safe order of seven migration Jobs;
- confirm backup and restore point;
- inspect idempotency and backward compatibility;
- validate rendered Jobs and immutable image references;
- choose one canary migration;
- document timeout, failure-stop, verification, and rollback decisions.

Exit gate: an operator-approved plan for exactly one migration canary. DT3 does
not authorize database mutation.

### DT4 — Controlled migration

Status: **BLOCKED BY DT3 APPROVAL**

Run one canary Job, verify `Complete` and schema state, then stop for approval.
Remaining Jobs run sequentially and stop at the first failure.

### DT5 — Immutable image build and publication

Status: **BLOCKED**

Build the explicit image targets, tag by commit SHA, push, and verify registry digests.

### DT6 — GitOps render and review

Status: **BLOCKED**

Render all runtime and migration references, inspect the complete diff, and do
not sync yet.

### DT7 — Controlled ArgoCD sync

Status: **BLOCKED BY OPERATOR APPROVAL**

Roll out incrementally while checking Vault injection, probes, logs, resources,
and restart behavior.

### DT8 — Service acceptance

Status: **BLOCKED**

Acceptance requires stable Ready pods, internal discovery, API Gateway routing,
ingress, observability, smoke/E2E tests, and tested rollback.

## Operator-control rules

1. Every phase begins with read-only plan/render and ends with recorded evidence.
2. No phase advances without explicit approval from Dita.
3. Credentials, tokens, private keys, and private CA material never enter Git.
4. Runtime and migration identities remain separate.
5. Application Deployments never run migrations automatically.
6. Production images are immutable and never use `latest`.
7. Cluster changes must match a reviewed Git changeset.
8. Temporary diagnostic resources must be labeled and removed.
9. Failure does not automatically authorize rollback, rotation, rerun, or sync.
10. kubectl must remain within supported minor skew of the server.

## Developer starting point

```bash
git switch main
git pull --ff-only origin main
git status --short --branch
./scripts/preflight-offline.sh
```

Developers must read this file, `docs/PHASE_HISTORY.md`, and the runbook for the
active phase before making deployment changes.

Allowed now: development, tests, documentation, offline render, and read-only
migration audit.

Not allowed without a later approval: migration, credential rotation, DT2
re-apply, workload deployment, ArgoCD sync, broad NetworkPolicy access, or
mutable production image tags.

## Current handoff

```text
DT2.2: PASS
Verified commit: 838c71d
Next phase: DT3 migration readiness audit
Migration: NOT RUN
Application: NOT DEPLOYED
ArgoCD sync: NOT RUN
```
