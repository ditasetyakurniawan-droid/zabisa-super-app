# Zabisa RBAC Matrix

Phase 3.4 establishes a centralized backend RBAC baseline. The Go `authz` package is the authorization authority used by services. The admin-web matrix mirrors it for navigation and UX only; hiding UI is never considered a security boundary.

| Role | Primary permissions |
| --- | --- |
| SUPER_ADMIN | all permissions, role/status administration, audit |
| ADMIN | operational administration across modules, user create/read, audit read; cannot mutate roles/status |
| OPERATOR | students, guardian linking, attendance, operational notifications |
| CONTENT_EDITOR | CMS content, kajian/event, content notifications |
| FINANCE | donation campaign/payment administration and verification |
| USTADZ | student read + tahfidz read/write |
| GURU_AGAMA | student read + academics read/write/publish |
| GURU_AKADEMIK | student read + academics read/write/publish |
| WALI_KELAS | student read + academics read + attendance read/write |
| GUARDIAN / public roles | no backoffice access |

## Security invariants

- Backend authorization remains authoritative even when admin-web hides a module.
- Backoffice login rejects customer-facing/public roles and revokes the newly-created session.
- Only `SUPER_ADMIN` can change an existing user's role or status.
- Role/status changes revoke every active session of the target user.
- The last active `SUPER_ADMIN` cannot be demoted or deactivated.
- A `SUPER_ADMIN` cannot remove their own active super-admin access.
- `ADMIN` may create operational accounts but may not create `ADMIN` or `SUPER_ADMIN` accounts.
- Audit records have no update/delete API.
- Legacy local role `TEACHER` is normalized to `GURU_AKADEMIK`; new data must use canonical role names.

## ABAC boundary

RBAC is not sufficient for staff object scope. A later assignment-scope vertical slice must restrict staff by unit/class/group/academic-year where required. For example, a teacher must not automatically gain write access to every student merely because the role has `academics.write`.

Until that scope model is implemented, this document does **not** claim class/unit ABAC is complete.
