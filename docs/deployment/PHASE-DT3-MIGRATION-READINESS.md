# DT3 — Controlled migration readiness

Status: **DT3.2 PASS / DT3.3 SOURCE HARDENING / DATABASE NOT MUTATED**

Source baseline: `cee801f`

## Audit findings

- Seven bounded contexts contain eighteen ordered SQL migration files.
- Each context owns a distinct database and a distinct Vault migrator identity.
- DT3.2 inventoried all seven live target databases read-only. Every database
  contained zero tables, zero `schema_migrations` rows and no checksum column.
- All temporary inventory Pods were removed after the successful run.
- Base manifests intentionally retain `REPLACE_SHA` until immutable images are built and rendered.
- DT3.3 adds a per-database MySQL advisory lock, exact source checksums and
  fail-closed handling for any future legacy unchecksummed records.
- The backup runbook states policy but no current backup/restore evidence has been supplied.

DT3 therefore does not authorize migration execution.

## Controlled order

| Wave | Service | Database | Migrations | Reason |
|---:|---|---|---:|---|
| -70 | content | `content_db` | 2 | Canary candidate; create-only and no cross-context dependency |
| -60 | identity | `identity_db` | 3 | Establish identity/audit foundation |
| -50 | student | `student_db` | 2 | Establish student records before dependent domains |
| -40 | tahfidz | `tahfidz_db` | 2 | Logically consumes student identifiers |
| -30 | academic | `academic_db` | 2 | Logically consumes student identifiers |
| -20 | donation | `donation_db` | 4 | Independent schema; logically references users |
| -10 | notification | `notification_db` | 3 | Downstream notification domain |

There are no cross-database foreign keys. Waves enforce deterministic execution
and stop later Jobs when an earlier PreSync hook fails. `backoffLimit: 0` keeps
failure handling under operator control.

## Canary rationale

`content` is the proposed canary because both files use `CREATE TABLE IF NOT
EXISTS`; it has no `ALTER TABLE` and no intra-schema foreign key. Selection is
not execution approval.

## Read-only schema inventory

First validate source only:

```bash
./scripts/run-zabisa-mysql-schema-inventory.sh --plan
./scripts/verify-dt3-source.sh
./scripts/preflight-offline.sh
```

Live inventory creates seven temporary, sequential Pods and runs only `SELECT`
queries through the existing per-service migrator identities:

```bash
DT3_CONFIRM=RUN-READ-ONLY-DT3-INVENTORY \
KUBECTL="$HOME/.local/bin/kubectl-zabisa-1.30.14" \
./scripts/run-zabisa-mysql-schema-inventory.sh --run
```

This is a Kubernetes temporary-resource mutation, but not a database mutation.
It requires an explicit operator decision and cleans every temporary Pod.

DT3.2 result (`2026-09-04`): **PASS**. `identity_db`, `content_db`,
`student_db`, `tahfidz_db`, `academic_db`, `donation_db` and
`notification_db` each reported `tables=0`, `migration_table=0` and
`migration_rows=0`. Report SHA-256:
`951809641f4c094f7abc8a800a6e7b26e97c78f6ce49e3acf82449429957e8b5`.

## Migration engine controls

- `GET_LOCK` serializes migration execution per target database.
- `RELEASE_LOCK` is attempted before the pinned connection returns to the pool.
- SHA-256 of the exact SQL file bytes is stored with the applied filename.
- A changed previously applied file fails with checksum drift instead of being
  silently accepted.
- A pre-existing migration table with rows but no checksum column fails closed
  and requires explicit operator baselining.
- Because DT3.2 proved every target database empty, first deployment can create
  the checksum-aware table without a legacy data conversion.
- MySQL DDL is not described as transactional. Repository tests restrict the
  eighteen current migrations to reviewed shapes and reject multi-statement
  `ALTER` files. The two existing single-statement `ALTER` files still require
  operator inspection after an interrupted run; they are not advertised as
  transactionally rollback-safe.

## Remaining blockers

1. Merge DT3.3 migration engine hardening and pass the remote CI gate.
2. Build/scan/push immutable service images and record Harbor digests.
3. Prove a current encrypted full backup and tested isolated restore, including
   timestamp, checksum, binlog coordinates, duration, row/table validation and
   operator.
4. Render the reviewed canary manifest with an approved immutable image.
5. Confirm Harbor image-pull authentication and the real GitOps repository.
6. Obtain explicit approval for exactly the `content` canary.

## Prohibited until all blockers close

- database migration;
- ArgoCD sync;
- application Deployment;
- manual execution of any migration container;
- automatic retry after a failed migration;
- editing or deleting an already-applied migration file.
