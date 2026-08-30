# Phase 3.5 Validation

Run:

```bash
npm run phase35:verify
npm run phase34:verify
npm run demo:verify
./scripts/verify-admin-runtime.sh
```

Expected Phase 3.5 coverage includes student mutation, guardian ownership transitions, attendance upsert, tahfidz target update, subject lifecycle, grade draft/publish immutability, report publish notification, donation campaign/payment-method lifecycle and notification inbox persistence.

If User & Access navigation fails, first run `./scripts/verify-admin-session-cache.sh` and inspect browser E2E in the next phase. Do not clear databases or weaken backend RBAC to recover a frontend navigation issue.
