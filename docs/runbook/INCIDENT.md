# Incident runbook

1. Identify impacted API/service from request_id/trace_id and ELK logs.
2. Protect data integrity first; disable a feature flag for unsafe transactional paths when required.
3. Do not mutate production databases manually without an approved incident procedure and audit record.
4. Roll back through GitOps to a known immutable image when safe.
5. Verify readiness, error rate, donation state consistency and notification backlog before closing.
