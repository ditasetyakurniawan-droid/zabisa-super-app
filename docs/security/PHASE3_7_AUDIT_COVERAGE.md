# Phase 3.7 Sensitive Mutation Audit Coverage

The audit path is append-only from normal administrative APIs. Service-local business transactions enqueue audit records in the same database transaction, then the outbox worker delivers them to Identity's audit read model.

Covered action families include:

- Identity: user creation and access changes.
- Student: student create/update, attendance upsert, guardian request/approve/reject/revoke.
- Tahfidz: entry create, target create/update.
- Academic: subject create/update, grade create/update/publish, report create/publish.
- Donation: campaign create/update, campaign update create, payment-method create/update, payment verification.
- Content: content create/update and kajian create/update.
- Notification: immediate notification create and scheduled notification create.

Audit records must preserve actor, action, resource, resource id, before/after where applicable, source service, request id, trace id, and timestamp. Secrets, passwords, refresh tokens, and bearer tokens must never be serialized into audit payloads.
