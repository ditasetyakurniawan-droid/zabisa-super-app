# DT3 — Controlled migration readiness

Status: **SOURCE HARDENING / DATABASE NOT MUTATED**

Baseline commit: `6553d80`

## Audit findings

- Seven bounded contexts contain eighteen ordered SQL migration files.
- Each context owns a distinct database and a distinct Vault migrator identity.
- The DT namespace currently contains no migration Job or application Pod.
- Base manifests intentionally retain `REPLACE_SHA` until immutable images are built and rendered.
- The migration engine records filenames but currently has no checksum validation or advisory lock.
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

## Remaining blockers

1. Capture the live seven-database schema inventory.
2. Prove a current encrypted full backup and tested isolated restore, including
   timestamp, checksum, binlog coordinates, duration, row/table validation and
   operator.
3. Add migration advisory locking and applied-file checksum drift detection,
   with tests, before any Job is run.
4. Build/scan/push immutable service images and record Harbor digests.
5. Render the reviewed manifests with the approved Git SHA.
6. Confirm Harbor image-pull authentication and the real GitOps repository.
7. Obtain explicit approval for exactly the `content` canary.

## Prohibited until all blockers close

- database migration;
- ArgoCD sync;
- application Deployment;
- manual execution of any migration container;
- automatic retry after a failed migration;
- editing or deleting an already-applied migration file.
