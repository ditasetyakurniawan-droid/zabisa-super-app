#!/usr/bin/env bash
set -euo pipefail

required_actions=(
  STUDENT_CREATED STUDENT_UPDATED
  GUARDIAN_LINK_REQUESTED GUARDIAN_LINK_APPROVED GUARDIAN_LINK_REJECTED GUARDIAN_LINK_REVOKED
  TAHFIDZ_ENTRY_CREATED
  GRADE_CREATED GRADE_UPDATED GRADE_PUBLISHED REPORT_PUBLISHED
  CAMPAIGN_CREATED CAMPAIGN_UPDATED PAYMENT_VERIFIED
  USER_CREATED USER_ACCESS_CHANGED
)

for action in "${required_actions[@]}"; do
  if ! grep -Rqs --include='*.go' "\"$action\"" services packages/go; then
    echo "ERROR: audit action missing from authored Go source: $action"
    exit 1
  fi
  echo "PASS audit action source marker: $action"
done

grep -q 'AuditEndpoint string' packages/go/platform/outbox/outbox.go
grep -q 'eventType == "Audit.Record"' packages/go/platform/outbox/outbox.go
grep -q 'POST", "/internal/v1/audit-events"' services/identity/main.go || grep -q 'http.MethodPost, "/internal/v1/audit-events"' services/identity/main.go
grep -q 'source_service' services/identity/migrations/003_cross_service_audit.sql
grep -q 'CREATE TABLE IF NOT EXISTS outbox_events' services/student/migrations/002_outbox.sql

if grep -RqsE 'Handle\([^\n]*(PATCH|PUT|DELETE)[^\n]*/api/v1/admin/audit' services/identity; then
  echo "ERROR: mutable admin audit route detected"
  exit 1
fi

echo "PASS cross-service append-only audit source invariants"
