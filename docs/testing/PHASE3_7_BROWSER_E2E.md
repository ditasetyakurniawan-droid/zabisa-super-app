# Phase 3.7 Browser E2E

The Backoffice E2E suite uses installed Google Chrome/Chromium and real client navigation through the Next.js BFF.

Critical checks:

- every SUPER_ADMIN sidebar module can be navigated repeatedly without page errors or HTTP 5xx;
- Data Santri create/update works from the actual form against the strict backend DTO;
- Guardian onboarding exposes the staged account/link/approval model using a narrow guardian directory;
- Tahfidz target create then PATCH edit does not send immutable `student_id` on update;
- Donation payment-method create then deactivate honors create/update DTO separation;
- Notification compose persists through the BFF;
- Audit Log renders cross-service provenance.

Trace and screenshot are retained on failure. Video is disabled so the suite does not depend on Playwright-managed ffmpeg when using the system browser.
