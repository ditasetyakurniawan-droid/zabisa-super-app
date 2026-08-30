# Backoffice

## Stack

- Next.js 16 App Router
- React 19
- TypeScript
- TanStack Query
- Backend-for-Frontend session proxy
- Playwright with installed system Google Chrome

Local URL:

`http://localhost:3001`

## Runtime

Production-shaped image uses Next.js standalone output and launches generated
`server.js`. Do not switch the image back to `next start` while
`output: "standalone"` is enabled.

Container:

- non-root user;
- healthcheck;
- standalone runtime;
- secure-cookie behavior is environment-configurable.

Local Compose explicitly disables Secure cookie over plain HTTP. Production
must enable Secure cookies behind HTTPS.

## Server-state rule

TanStack Query is the source of truth for Backoffice server state. Do not add
ad-hoc `useEffect` data loaders.

Authentication session uses one centralized query key and one normalized data
shape. A previous `User & Access` navigation failure was caused by conflicting
query shapes under the same session key. Do not duplicate session-query
implementations.

## Forms

Important invariant:

Do not use `event.currentTarget` after an async boundary.

Bad:

```tsx
await api(...);
event.currentTarget.reset();
```

Good:

```tsx
const formEl = event.currentTarget;
await api(...);
formEl.reset();
```

The repo contains a source invariant for this class of bug.

## Accessibility

Sidebar icon glyphs are decorative and hidden from the accessibility tree.
Links expose stable human-readable accessible labels.

Attendance and other dependency forms use explicit `htmlFor`/`id` associations.
Do not rely on wrapped labels whose accessible names can absorb option text.

## RBAC-aware UI

Frontend permission checks improve usability but are not the security boundary.
Backend authorization remains authoritative.

Read-only roles must not see mutation controls they cannot execute.

## Critical modules

Current Backoffice modules include:

- Dashboard
- User & Access
- Audit Log
- Content Management
- Kajian
- Data Santri
- Wali & Linking
- Tahfidz
- Kehadiran
- Akademik & Report
- Donation
- Notification

## Browser E2E

Use:

```bash
npm run admin:e2e
```

Playwright:

- system Chrome;
- one worker in current local suite;
- trace retained on failure;
- screenshot on failure;
- video disabled to avoid unnecessary Playwright ffmpeg dependency.

At the Phase 3.7.6 lock, all 12 critical browser tests pass.
