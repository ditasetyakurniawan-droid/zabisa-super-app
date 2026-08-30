# Security baseline

- Argon2id password hashing.
- Short-lived signed access tokens and revocable refresh sessions.
- Object-level authorization for guardian/student resources.
- Request validation, rate-limit hooks, CORS allowlist, secure headers, upload validation, webhook signature verification and idempotency.
- Sensitive values must come from Vault.
- Do not log passwords, OTPs, tokens, private student details, or payment secrets.
- Audit trail for sensitive mutations.
