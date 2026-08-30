# ADR-008: Central backend RBAC permission matrix

Status: Accepted for Phase 3.4.

## Decision

Use `packages/go/platform/authz` as the backend role-to-permission policy baseline. Each service authorizes a route by permission rather than maintaining independent role maps.

Admin-web mirrors the matrix only to improve navigation and prevent misleading UI. Backend checks remain mandatory.

## Why

Independent role lists were already drifting (`TEACHER` vs `GURU_AKADEMIK`) and make privilege review difficult. Permission-based middleware provides clearer boundaries and a single review point while preserving bounded-context services.

## Consequences

- role changes can be reviewed centrally;
- service endpoints express required capability;
- no direct cross-service database query is introduced;
- object-level/class-level authorization remains a separate ABAC concern and must not be inferred from RBAC.
