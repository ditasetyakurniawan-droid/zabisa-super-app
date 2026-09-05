# MySQL backup and restore

A backup is valid for a migration gate only after it has been restored and
verified in an isolated target. Creating a dump alone is not recovery proof.

## Required controls

- MySQL binary logs are enabled with retention aligned to the approved RPO.
- A full backup is encrypted and copied to storage independent of `db-dt`.
- Backup credentials and encryption keys never enter Git, shell history or the
  evidence report.
- Restore drills target an isolated server/database and cannot overwrite DT.
- Backup and restore commands are reviewed for the deployed MySQL version.

## Evidence record

Record all of the following before requesting migration approval:

| Evidence | Required value |
|---|---|
| Source | MySQL endpoint identity and server version; no credential values |
| Scope | All seven Zabisa databases and migration metadata |
| Backup | UTC start/end, method, byte size and SHA-256 |
| Recovery position | Binlog file/position or equivalent consistent snapshot coordinates |
| Storage | Independent encrypted destination and retention policy |
| Restore | Isolated target, UTC start/end and elapsed duration |
| Validation | Database/table counts, representative row counts and migration metadata |
| Operator | Person executing and person reviewing |
| Cleanup | Isolated restore disposition and confirmation DT was not modified |

## Pre-migration gate

The operator must confirm:

1. the evidence was produced recently enough for the approved RPO;
2. the archive checksum matches before and after transfer;
3. the isolated restore completed successfully;
4. validation matches the source snapshot;
5. recovery time is acceptable for the approved RTO;
6. the exact recovery point is referenced by the migration approval.

If any item is missing, stale or ambiguous, stop. Do not run a migration,
ArgoCD sync, destructive cleanup or an untested restore against DT.

## Executable DT5 control

Use `scripts/run-zabisa-dt5-backup-restore.sh --run` only through the DT5–DT8
controlled rollout. It uses the existing pinned Oracle MySQL image, TLS
`VERIFY_CA`, consistent snapshot coordinates, AES-256/PBKDF2 encryption and a
`--network none` restore container. Review the retained evidence before entering
the separate content-canary confirmation.

The script is intentionally not a restore-to-DT command. Restoring the backup
to DT remains a separate incident operation requiring an exact target, outage
plan and approval.

## DT3 checkpoint

DT3.2 proved all seven target schemas empty on `2026-09-04`. This simplifies the
first migration but does not waive the backup-and-restore gate: the MySQL server
can host other controlled data and the recovery procedure itself must be proven.
