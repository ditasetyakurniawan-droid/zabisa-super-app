# Audit Coverage Matrix

| Sensitive domain | Action examples | Source |
| --- | --- | --- |
| Identity/access | USER_CREATED, USER_ACCESS_CHANGED | identity-service |
| Student | STUDENT_CREATED, STUDENT_UPDATED | student-service |
| Guardian link | GUARDIAN_LINK_REQUESTED, GUARDIAN_LINK_APPROVED, GUARDIAN_LINK_REJECTED, GUARDIAN_LINK_REVOKED | student-service |
| Tahfidz | TAHFIDZ_ENTRY_CREATED | tahfidz-service |
| Academic grade | GRADE_CREATED, GRADE_UPDATED, GRADE_PUBLISHED | academic-service |
| Academic report | REPORT_PUBLISHED | academic-service |
| Donation campaign | CAMPAIGN_CREATED, CAMPAIGN_UPDATED | donation-service |
| Payment verification | PAYMENT_VERIFIED | donation-service |

Normal Backoffice roles only have `audit.read` when granted by RBAC. There is no mutation route for audit records.
