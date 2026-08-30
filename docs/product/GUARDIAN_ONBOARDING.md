# Guardian Onboarding and Parent-Student Linking

Production flow:
1. ADMIN or SUPER_ADMIN creates a guardian account in Identity with role `GUARDIAN`.
2. Authorized staff selects the guardian and student and creates a relationship request.
3. Relationship starts in `PENDING`.
4. Authorized staff approves it after operational verification.
5. Only `APPROVED` grants object-level access to private student data.
6. Revoke immediately removes that access.
7. `REVOKED` or `REJECTED` may be requested again, but returns to `PENDING` and requires a new approval.

Creating an account never auto-links a student and creating a relationship never auto-approves it. Guardian accounts are mobile/private-area accounts and are intentionally denied Backoffice access.
