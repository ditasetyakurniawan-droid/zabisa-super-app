# Audit Delivery Runbook

## Verification

Run:

```bash
npm run phase36:audit
```

The verifier creates only clearly labeled development fixtures and checks that cross-service audit events arrive in Identity with `source_service`, `request_id`, and `trace_id`.

## Backlog check

Pending source audit records are visible in the owning service database as `outbox_events` rows where `event_type='Audit.Record'` and `processed_at IS NULL`.

A growing backlog usually indicates:
- Identity unavailable;
- invalid/mismatched `INTERNAL_SERVICE_KEY`;
- incorrect `AUDIT_SERVICE_URL`;
- database/network failure.

Do not delete pending audit outbox rows to recover service. Correct the dependency and allow retry.

## Append-only invariant

There is no admin API to update/delete audit logs. Emergency retention/purge policy, when legally required, must be implemented as controlled infrastructure/data-governance work rather than a normal Backoffice action.
