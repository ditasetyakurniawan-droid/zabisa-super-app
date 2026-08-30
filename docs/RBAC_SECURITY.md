# RBAC and Security

## Security model

Backend authorization is the authoritative boundary. UI permission checks are
only usability controls.

Current principal roles include:

- `SUPER_ADMIN`
- `ADMIN`
- `OPERATOR`
- `CONTENT_EDITOR`
- `FINANCE`
- `USTADZ`
- `GURU_AGAMA`
- `GURU_AKADEMIK`
- `WALI_KELAS`
- `GUARDIAN`

Some code may support additional public/donor roles. Do not broaden staff
permissions merely to make a page convenient.

## Verified boundary examples

- CONTENT_EDITOR may manage content but is denied Donation/Student operations
  outside its permissions.
- FINANCE may access Donation but is denied Content.
- OPERATOR may access Student/Attendance but not Donation.
- USTADZ may access Tahfidz but not Academic.
- GURU_AKADEMIK may access Academic but not Tahfidz.
- GUARDIAN is denied admin APIs and Backoffice login.
- Role change revokes prior session/token effectiveness.
- Self-demotion protection returns conflict.

## Narrow candidate endpoints

Do not give broad `users.read` simply because a workflow needs a picker.

Use scoped candidates:

- Guardian linking → guardian candidates;
- Notification compose → notification candidates.

This preserves least privilege.

## Guardian object authorization

Private student data requires an APPROVED guardian relationship. Backend checks
the actual student relationship for private Tahfidz/Academic/Report access.

Revocation removes access.

Never implement guardian authorization only by hiding buttons in the client.

## Secrets

Do not commit:

- production JWT secrets;
- database passwords;
- provider keys;
- FCM/APNs credentials;
- payment-provider secrets;
- private signing material.

Development seed credentials belong in local environment/bootstrap tooling and
must not be documented as production secrets.

## Dependency policy

Do not use `npm audit fix --force` as a blanket remediation. Classify
vulnerabilities, upgrade intentionally and regression-test dependency changes.
