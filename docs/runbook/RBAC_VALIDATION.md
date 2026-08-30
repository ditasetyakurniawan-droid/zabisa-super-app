# RBAC Validation Runbook

Local/DT verification should run `scripts/verify-phase34-rbac.sh` against the API gateway.

Expected examples:

- CONTENT_EDITOR: content/kajian allowed, donation/students denied.
- FINANCE: donation allowed, CMS/academic denied.
- OPERATOR: students/guardian/attendance allowed, donation/content denied.
- USTADZ: tahfidz allowed, academic write denied.
- GURU_AKADEMIK: academic allowed, tahfidz write denied.
- GUARDIAN: admin endpoints denied and admin-web login denied.

Any unexpected 2xx on a forbidden capability is a release blocker.
