# Zabisa Feature Matrix

This matrix prevents visual scaffolding from being reported as finished functionality.

| Domain | Capability | Status | Notes |
|---|---|---|---|
| Public | Home, kajian list/detail, programs/news/profile/gallery metadata | Implemented | CMS driven, public without login |
| Backoffice | Multi-page operations console | Implemented | Dashboard, CMS, kajian, donation, students, linking, tahfidz, academics, attendance, notifications, access, audit |
| Identity | Login, refresh rotation, logout, `/me`, local seeded roles | Implemented | HttpOnly BFF for admin, Keychain/Keystore for mobile |
| Guardian | Approved parent-student relationship | Implemented | Demo guardian linked locally; backend object access enforced |
| Tahfidz | Entry, quality fields, target, history | Implemented | Entry creates transactional outbox event |
| Academic | Configurable subjects, grades, publish, report lifecycle | Implemented | Signed server PDF generation remains pending |
| Attendance | Record and guardian history | Implemented | Backend authorization enforced |
| Donation | Campaign, methods, idempotent donation, manual verification, history, campaign updates | Implemented | Production gateway provider credentials pending |
| Notification | Inbox, read state, broadcast/target, schedule, deep-link payload | Implemented | FCM/APNs production adapter credentials pending |
| Audit | Identity/access audit read model | Partial | Extend immutable audit emission to every sensitive bounded context |
| Media | S3/MinIO object storage, safe upload, thumbnail, ACL separation | Pending | Next production milestone, no fake upload UI exposed |
| Reports | Report lifecycle | Partial | Server PDF + signed temporary URL pending |
| Payment | Manual transfer | Implemented | Midtrans/Xendit/DOKU abstraction and webhook adapter pending credential selection |
| Push | Notification persistence/events | Implemented | Real FCM/APNs delivery pending credentials/configuration |
| ABAC | Guardian object access | Implemented | Staff campus/unit/class/group ABAC is pending master organizational model |
| Feature flags | Backend-controlled emergency toggles | Pending | Planned platform service/config table |
| Analytics | Provider abstraction | Pending | Must exclude student/private payloads |
| Observability | Structured logs, request IDs, health endpoints | Foundation | Complete OTel exporters/metrics dashboards in hardening milestone |
| Platform | Docker/K8s/Vault/Harbor/ArgoCD/Sonar artifacts | Foundation | DT integration must be validated against actual credentials and cluster policy |

## Completion policy

A row is only moved to Implemented after its UI/API/database/authorization/validation/error states/tests/contracts/deployment artifacts are present. External integrations remain explicitly Pending until real sandbox/production credentials are connected and verified.
