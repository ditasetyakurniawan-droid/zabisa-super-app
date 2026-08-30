# Project State — Phase 3.7.6 Locked Baseline

## Executive status

Zabisa currently has a production-shaped local platform composed of:

- React Native mobile application;
- Next.js Backoffice;
- Go API Gateway;
- Go bounded-context services;
- MySQL 8.4;
- NATS;
- MinIO;
- append-only cross-service audit delivery;
- backend-enforced RBAC and object-level guardian authorization.

Phase 3.7.6 is the first point where the Backoffice critical functional matrix
is verified through a real Chrome browser, not only API-level scripts.

## Verified at lock

### Backoffice

The real Chrome matrix covers twelve critical scenarios:

1. repeated navigation across all SUPER_ADMIN modules, including repeated
   `User & Access` navigation;
2. Data Santri create and update;
3. Guardian onboarding UI and staged relationship flow;
4. Tahfidz target create and edit;
5. Donation payment-method create and deactivate;
6. Notification compose;
7. Content Management create and update;
8. Kajian create and update;
9. Attendance upsert;
10. Academic Subject create and deactivate;
11. User & Access create and deactivate;
12. Audit Log cross-service provenance.

All twelve passed at the project lock.

### Backend/API

Verified:

- strict JSON decoding;
- student create/update contract;
- Tahfidz target POST/PATCH split;
- payment-method create/update DTO split;
- narrow guardian/notification candidate APIs;
- service-side RBAC;
- guardian object authorization;
- guardian relationship request → approve → revoke → re-request;
- stale-token rejection after role changes;
- self-demotion protection;
- manual donation verification;
- publish workflows for academic data;
- content/kajian public read-back;
- cross-service append-only audit delivery.

### Mobile

Verified quality/runtime foundation:

- TypeScript;
- ESLint;
- Jest;
- Guardian API E2E;
- populated development data across Tahfidz, grades, attendance, reports and
  notifications;
- Android physical-device deployment workflow;
- sky-blue production-shaped UI baseline;
- standalone login outside bottom tabs;
- secure session storage;
- contextual deep-link parsing and native URL scheme configuration.

Physical-device UI was iteratively reviewed during development, but the mobile
screen-level automated coverage is still incomplete and is explicitly tracked
as future work.

## Lock principle

This is a **development baseline lock**, not a production launch declaration.

Production push notification providers, production payment providers, iOS
release signing, final Sonar/CI/CD policy and production deployment remain
separate completion gates.
