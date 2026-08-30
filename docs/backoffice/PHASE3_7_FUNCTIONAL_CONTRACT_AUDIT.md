# Phase 3.7 Functional Contract Audit

Phase 3.7 closes the gap between API-level verification and the payloads emitted by the real Backoffice UI.

## Contract rules

- JSON decoding remains strict. Unknown fields are rejected; the backend is not weakened to accommodate incorrect UI payloads.
- Student create and update share the explicit fields `student_no`, `full_name`, `photo_url`, `class_name`, `program_name`, `academic_year`, and `status`.
- Tahfidz target ownership (`student_id`) is set only at create time. PATCH changes only target values.
- Donation payment methods start active. `active` belongs to the update lifecycle and is not sent on create.
- Backoffice rendering is permission-aware: read permission must not imply write controls.
- Guardian and notification workflows use narrow candidate endpoints instead of granting broad `users.read` to operational roles.
- Local HTTP Backoffice sessions explicitly set `ZABISA_COOKIE_SECURE=false`; production defaults remain secure unless deliberately configured otherwise.

## Verification layers

1. Static authored-source contract invariants.
2. Scoped Go unit/build tests.
3. TypeScript, ESLint zero-warning, and Next.js production build.
4. API contract smoke using real strict decoders.
5. Phase 3.5 operational API E2E for all major domains.
6. Phase 3.6 cross-service append-only audit regression.
7. Real Google Chrome E2E through Backoffice BFF for navigation and representative strict-DTO mutations.
8. Mobile populated regression.

A UI form is not considered functional solely because it renders.
