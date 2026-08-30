# API Contract Rules

## Strict decoding

Unknown JSON fields are rejected intentionally.

A UI/API mismatch must be fixed by changing the correct DTO or the correct
frontend payload. Do not loosen the global decoder.

## Contract fixes already learned

### Student create

UI and backend must agree on fields including student status/profile metadata.

### Tahfidz target

Create and update DTOs are different:

```text
POST:
student_id
target_juz
target_date

PATCH:
target_juz
target_date
```

`student_id` is not mutable through target PATCH.

### Donation payment method

```text
POST:
create fields
(no active lifecycle flag)

PATCH:
editable fields
active lifecycle may be changed
```

### Guardian candidates

Guardian linking uses a narrow candidate endpoint, not broad identity user
listing.

### Notification candidates

Notification audience selection uses a narrow endpoint rather than requiring
`users.read`.

## Mutation rule

For critical browser workflows, tests should assert the real mutation HTTP
response, then verify UI state/read-back.

Avoid tests that only wait for a success string without observing the network
mutation.

## Error contracts

Prefer deterministic domain errors:

- validation errors;
- duplicate email conflict;
- forbidden;
- not found;
- immutable/published conflict;
- stale session/unauthorized.

Do not collapse all database errors into misleading generic conflicts.
