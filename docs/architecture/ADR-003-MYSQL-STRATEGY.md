# ADR-003: MySQL database strategy

Status: Accepted.

## Decision
Use MySQL 8.4 LTS as the production baseline. One physical cluster may host multiple logical databases initially: `identity_db`, `content_db`, `student_db`, `tahfidz_db`, `academic_db`, `donation_db`, and `notification_db`. Each service owns its database and MUST NOT query another service database directly. Cross-domain access uses HTTP contracts or domain events.

## Rationale
The target local and server infrastructure is MySQL. MySQL 8.4 is an LTS baseline with broad operational support. SQL uses InnoDB, `utf8mb4`, UTC timestamps, foreign keys only inside a bounded context, explicit indexes, and transactions for critical writes.

## Operational consequences
- Secrets come from Vault in Kubernetes.
- Use binary logs and tested backups for point-in-time recovery readiness.
- Use expand/migrate/contract for rolling schema changes.
- UUIDs are stored as `CHAR(36)` initially for readability and portability; a future ADR may migrate hot tables to `BINARY(16)` after profiling.
