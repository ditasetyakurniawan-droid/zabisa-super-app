# Audit and Observability

## Append-only audit objective

Sensitive operations are captured with enough context to answer:

- who performed the action;
- what action happened;
- which resource/resource ID changed;
- before/after state where relevant;
- source service;
- request/trace correlation;
- timestamp;
- network/user-agent context where available.

## Covered sensitive domains

Current audit markers cover the major mutation classes developed through
Phase 3.7:

### Identity

- `USER_CREATED`
- `USER_ACCESS_CHANGED`

### Student

- `STUDENT_CREATED`
- `STUDENT_UPDATED`
- `ATTENDANCE_UPSERTED`
- `GUARDIAN_LINK_REQUESTED`
- `GUARDIAN_LINK_APPROVED`
- `GUARDIAN_LINK_REJECTED`
- `GUARDIAN_LINK_REVOKED`

### Tahfidz

- `TAHFIDZ_ENTRY_CREATED`
- `TAHFIDZ_TARGET_CREATED`
- `TAHFIDZ_TARGET_UPDATED`

### Academic

- `SUBJECT_CREATED`
- `SUBJECT_UPDATED`
- `GRADE_CREATED`
- `GRADE_UPDATED`
- `GRADE_PUBLISHED`
- `REPORT_CREATED`
- `REPORT_PUBLISHED`

### Donation

- `CAMPAIGN_CREATED`
- `CAMPAIGN_UPDATED`
- `CAMPAIGN_UPDATE_CREATED`
- `PAYMENT_METHOD_CREATED`
- `PAYMENT_METHOD_UPDATED`
- `PAYMENT_VERIFIED`

### Content

- `CONTENT_CREATED`
- `CONTENT_UPDATED`
- `KAJIAN_CREATED`
- `KAJIAN_UPDATED`

### Notification

- `NOTIFICATION_CREATED`
- `NOTIFICATION_SCHEDULED`

## Delivery

Services use local transactional audit/outbox patterns where developed.
Delivery into the central audit read model is asynchronous.

Do not write directly into another service's database.

## Correlation

Backoffice BFF forwards request/trace correlation headers. Keep propagation
through:

- `X-Request-ID`
- `traceparent`
- forwarded network/user-agent context

## Audit verifier lesson

Do not put a large audit JSON response into an environment variable before
executing Python. Linux `ARG_MAX` can be exceeded.

Current verifier streams audit JSON over stdin.

## Remaining observability work

The audit trail is not a substitute for production observability. Next phases
should add/finish:

- structured centralized logs;
- OpenTelemetry traces;
- service metrics;
- dashboards;
- SLOs/alerts;
- provider delivery metrics.
