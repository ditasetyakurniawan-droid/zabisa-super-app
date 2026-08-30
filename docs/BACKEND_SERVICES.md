# Backend Services

## Services

### `api-gateway`

Public entry point and service routing. Keep service topology hidden from
clients. Narrow admin candidate routes for Guardian and Notification are routed
here.

### `identity`

Responsibilities:

- authentication;
- user lifecycle;
- role/status changes;
- session revocation;
- centralized append-only audit read model;
- narrow identity candidates for authorized workflows.

Security-sensitive behavior:

- duplicate email has deterministic conflict behavior;
- stale JWT is rejected after role-changing session revocation;
- self-demotion of the current super administrator is blocked;
- Guardian accounts are denied Backoffice access.

### `content`

Responsibilities:

- generic public content;
- Kajian;
- publish/unpublish lifecycle;
- public read models.

Sensitive mutations are audited.

### `student`

Responsibilities:

- student master data;
- attendance;
- guardian relationship state machine;
- Guardian linked-student read model.

Guardian relationships are explicit objects and are never inferred from weak
attributes such as student number or date of birth.

Relationship lifecycle:

`PENDING → APPROVED → REVOKED/REJECTED`

A revoked/rejected relationship can be requested again but returns to PENDING
and requires approval again.

### `tahfidz`

Responsibilities:

- Tahfidz entries;
- Tahfidz targets;
- Guardian-facing Tahfidz data.

Important contract:

- target POST includes `student_id`;
- target PATCH does **not** accept `student_id`.

### `academic`

Responsibilities:

- subjects;
- grades;
- reports;
- publication lifecycle.

Published academic records are treated as controlled/immutable state rather
than ordinary generic CRUD.

### `donation`

Responsibilities:

- campaigns;
- campaign updates;
- payment methods;
- donation transactions;
- manual verification baseline.

Important contract:

- Payment Method POST does not accept lifecycle `active`;
- Payment Method PATCH controls active/inactive lifecycle.

Production external payment-provider settlement is not yet claimed complete.

### `notification`

Responsibilities:

- notification persistence;
- scheduling baseline;
- user inbox;
- local transactional outbox;
- guardian notifications triggered by academic/Tahfidz flows.

Production FCM/APNs delivery remains pending external credentials/provider
configuration.

## Data ownership

Canonical logical databases:

- `identity_db`
- `content_db`
- `student_db`
- `tahfidz_db`
- `academic_db`
- `donation_db`
- `notification_db`

Never implement cross-service joins by directly querying another service's
database.
