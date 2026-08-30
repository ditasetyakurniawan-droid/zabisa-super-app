# Threat model

Primary assets: child/student records, guardian relationships, grades, tahfidz records, authentication tokens, donation transactions, and payment webhooks. Primary threats: BOLA/IDOR, credential stuffing, token theft, webhook spoofing/replay, SQL injection, over-privileged staff, unsafe uploads, and accidental PII logging. Controls map to OWASP API Security principles and are enforced at backend boundaries.
