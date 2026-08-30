# Phase 3.4 - Backoffice RBAC and CMS Vertical Slice

## Scope

1. Central Go RBAC permission matrix used by bounded-context services.
2. Backoffice internal-role login gate.
3. Role-aware navigation and dashboard.
4. SUPER_ADMIN role/status management with session revocation and lockout safeguards.
5. Identity audit before/after payload for access changes, plus request/trace correlation.
6. CMS content edit/publish/unpublish.
7. Kajian edit/publish with existing transactional-outbox notification behavior.
8. Integration verification across representative roles.

## Definition of done for this phase

This phase is only considered passed when:

- Go authz unit tests pass;
- service Go tests pass;
- admin-web TypeScript, lint, and production build pass;
- representative RBAC API checks return expected 200/403 results;
- content editor can create/update CMS content through real API;
- published content is visible from public API;
- guardian login is rejected by backoffice;
- existing mobile/demo E2E remains green.

## Not claimed complete

- class/unit/group ABAC staff assignments;
- full audit coverage for every sensitive bounded-context operation;
- external FCM/APNs credentials;
- production payment-provider credentials;
- production deployment hardening milestone.

## ESLint 9 flat configuration

The Next.js 16 backoffice uses the ESLint 9 flat-config entrypoint
`apps/admin-web/eslint.config.mjs` with `eslint-config-next/core-web-vitals`
and `eslint-config-next/typescript`.

TypeScript compilation remains a blocking quality gate. Legacy explicit `any`
usage in generic admin table/resource plumbing is temporarily reported as a
lint warning and must be removed as each operational CRUD module gains typed
contracts. No ESLint rule is disabled for security, React Hooks, accessibility,
or Core Web Vitals.

## React 19 effect lint policy

The current operational backoffice screens predate the React 19
`react-hooks/set-state-in-effect` advisory rule and use explicit asynchronous
load functions triggered by effects. For Phase 3.4 the rule is kept visible as
a warning, not disabled, so RBAC/CMS integration validation can remain blocking.

`rules-of-hooks` and `exhaustive-deps` remain errors. Phase 3.5 will move remote
server state to TanStack Query and remove this temporary policy together with
legacy generic `any` warnings. This is tracked technical debt, not a claim that
the affected screens are fully hardened.
