# ADR-009: Backoffice Operational Lifecycles

## Status
Accepted for Phase 3.5.

## Context
Zabisa stores student, educational, relationship and donation records where generic destructive CRUD is unsafe and undermines auditability.

## Decision
Use explicit domain lifecycles instead of generic delete:

- student: ACTIVE / INACTIVE / GRADUATED;
- guardian relationship: PENDING / APPROVED / REJECTED / REVOKED;
- subject: active / inactive;
- grade: draft -> published, with published records immutable until a correction workflow exists;
- report: DRAFT -> PUBLISHED;
- campaign: ACTIVE / PAUSED / COMPLETED / ARCHIVED;
- payment method: active / inactive;
- attendance: upsert on the student/date natural key.

Private academic/tahfidz read models use backend object-level relationship authorization for guardians. Frontend menu visibility is never treated as authorization.

## Consequences
Operational data remains recoverable and auditable. A subsequent audit-hardening phase must record before/after state for all sensitive mutations.
