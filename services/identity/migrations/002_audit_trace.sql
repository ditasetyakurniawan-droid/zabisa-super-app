ALTER TABLE audit_logs
  ADD COLUMN trace_id VARCHAR(64) NULL AFTER request_id,
  ADD INDEX idx_audit_actor_created(actor_id,created_at),
  ADD INDEX idx_audit_trace(trace_id);
