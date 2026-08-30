# Requirements Traceability

Status values:

- **VERIFIED** — implemented and exercised by current automated/manual evidence.
- **PARTIAL** — meaningful implementation exists but production completion gate remains.
- **PENDING** — intentionally future work.

| Requirement area | Status | Current evidence |
|---|---|---|
| Public Content/Kajian | VERIFIED | API regression + Backoffice Browser E2E |
| Donation campaigns/payment methods | VERIFIED for manual/local flow | Browser/API regression |
| External production payment provider | PENDING | Provider credentials/integration not finalized |
| Guardian linked students | VERIFIED | Guardian onboarding + demo/mobile E2E |
| Guardian Tahfidz | VERIFIED | API/demo/mobile flow |
| Guardian grades/reports | VERIFIED | API/demo/mobile flow |
| Attendance | VERIFIED | API + real Chrome Backoffice E2E + Guardian demo |
| Notification inbox | VERIFIED | API/demo/mobile flow |
| Production push delivery FCM/APNs | PENDING | External credential/provider gate |
| Backoffice User & Access | VERIFIED | RBAC + Browser E2E |
| Backoffice Student CRUD | VERIFIED | Strict API + Browser E2E |
| Backoffice Guardian Linking | VERIFIED | API state machine + Browser UX |
| Backoffice Tahfidz target | VERIFIED | Strict POST/PATCH + Browser E2E |
| Backoffice Academic subject | VERIFIED | API + Browser E2E |
| Grade/report publication | VERIFIED | API operational regression |
| Backoffice Donation operations | VERIFIED | API + Browser E2E |
| Backoffice Notification compose | VERIFIED | Browser/API |
| Backend RBAC | VERIFIED | role matrix regression |
| Guardian object authorization | VERIFIED | linked/unlinked/revoked tests |
| Append-only sensitive audit | VERIFIED for covered mutation matrix | Phase 3.6/3.7 audit regression |
| Backoffice runtime health | VERIFIED | standalone + health + repeated authenticated requests |
| Real browser critical matrix | VERIFIED | 12/12 Playwright |
| Mobile Android physical development | VERIFIED baseline | physical OPPO deployment/review |
| Mobile automated screen coverage | PARTIAL | low overall unit coverage |
| iOS native release validation | PENDING | requires macOS/Xcode/signing |
| SonarQube final quality gate | PARTIAL | config exists; final CI policy pending |
| GitHub CI/CD | PENDING | next roadmap |
| Production observability/SLO | PARTIAL | correlation/audit exists; full OTel/metrics pending |
| Production deployment | PENDING | staging/prod infrastructure not completed |
