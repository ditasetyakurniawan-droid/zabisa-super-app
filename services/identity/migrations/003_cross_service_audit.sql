ALTER TABLE audit_logs
  ADD COLUMN source_service VARCHAR(80) NULL AFTER resource_id,
  ADD INDEX idx_audit_source_created(source_service,created_at);
