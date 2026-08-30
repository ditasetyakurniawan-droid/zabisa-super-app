# Phase 3.5 Operational Backoffice

## Goal

Turn the existing Zabisa Backoffice into an operational control plane using real service APIs and lifecycle-safe mutations. This phase does not introduce hard delete for educational or financial records.

## User & Access navigation hotfix

`AppShell` and `User & Access` previously registered the same TanStack Query key, `auth/session`, with incompatible result shapes. A client navigation could therefore consume a cache entry with the wrong shape. The session query is now centralized in `lib/session.ts`; both consumers use `useSessionUser()` and share one result contract.

An authored-source invariant blocks future duplicate literal `auth/session` query functions outside the centralized module.

## Operational modules

- Content and Kajian: existing create/edit/publish/unpublish lifecycle retained.
- Student: create, update profile, lifecycle status.
- Guardian linking: create request, approve, reject, revoke.
- Attendance: idempotent operational upsert per student/date.
- Tahfidz: input entry and create/update target.
- Academics: configurable subject lifecycle, grade draft/edit/publish, report draft/publish.
- Donation: campaign lifecycle, configurable payment-method lifecycle, campaign update and manual verification UI.
- Notification: compose, schedule, targeted/broadcast history.
- User & Access: centralized session cache plus existing backend-enforced RBAC.

## Safety decisions

- No generic hard delete for student, subject, campaign, grade, report, attendance, or financial records.
- Published grades are immutable until a dedicated correction workflow with full audit is implemented.
- Private student read endpoints for grades, reports and tahfidz enforce object-level guardian ownership in backend services; authorized staff roles bypass via explicit permission.
- Development verifier leaves clearly labelled DEVELOPMENT DATA and deactivates/archives fixtures when possible.

## Remaining Definition-of-Done gap

Phase 3.5 deliberately does not claim complete audit coverage for every sensitive mutation. Cross-service append-only audit hardening is the next gate. Production FCM/APNs and external production payment-provider credentials are also outside this phase.
