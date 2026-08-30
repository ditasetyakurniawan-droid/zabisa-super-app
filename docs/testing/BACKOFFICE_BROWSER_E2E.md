# Backoffice Browser E2E

Phase 3.6 adds Playwright browser regression tests using the system Chrome/Chromium executable instead of downloading an additional browser binary.

Run:

```bash
npm run admin:e2e
```

Coverage includes:
- real Backoffice login;
- repeated client-side navigation through User & Access, Audit, Student, Tahfidz and Academic routes;
- rejection of page errors and HTTP 5xx responses;
- Guardian onboarding staged-flow UI;
- cross-service Audit source column.

The repeated navigation test permanently covers the previously reproduced `/access` client-navigation regression.
