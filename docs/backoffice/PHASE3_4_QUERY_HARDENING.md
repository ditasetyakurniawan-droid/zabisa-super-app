# Phase 3.4 Backoffice Query-State Hardening

## Context

The initial Phase 3.4 Backoffice pages loaded server data by invoking state-setting
`load()` functions from `useEffect`. React 19's recommended lint rules correctly
flag this pattern when it synchronously sets loading state from the effect.

## Decision

Backoffice server state is managed with TanStack Query, using the same query
library already selected for Zabisa Mobile.

The backoffice now has:

- a single `QueryClientProvider`;
- typed API query keys;
- typed domain rows instead of explicit `any`;
- query invalidation after successful mutations;
- derived loading/error states instead of effect-driven copies;
- no `useEffect` data-loading pattern in the admin application;
- Next Router navigation for logout/session handling instead of direct
  `location.href`;
- `@typescript-eslint/no-explicit-any` restored as a blocking error.

## Security boundary

TanStack Query is only client-side server-state orchestration. It does not
authorize requests. Every sensitive endpoint remains protected by backend RBAC
and object-level authorization. A hidden menu or cached query is never treated
as an authorization control.

## Cache policy

Backoffice query defaults:

- stale time: 15 seconds;
- retry: one attempt;
- window-focus refetch: disabled;
- mutation success: explicit invalidation of affected query keys;
- query cache is cleared on logout before returning to the login screen.

Sensitive data is not persisted to browser storage by this phase.

## Definition of Done impact

This change addresses Backoffice UX/error/loading quality and prevents a lint
suppression workaround. It does not change the Phase 3.4 RBAC permission model,
audit semantics, or API contracts.
