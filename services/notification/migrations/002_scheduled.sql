CREATE TABLE IF NOT EXISTS scheduled_notifications (
  id CHAR(36) PRIMARY KEY,
  user_id CHAR(36) NULL,
  type VARCHAR(64) NOT NULL,
  title VARCHAR(220) NOT NULL,
  message VARCHAR(1000) NOT NULL,
  deep_link VARCHAR(512) NULL,
  scheduled_at DATETIME(6) NOT NULL,
  processed_at DATETIME(6) NULL,
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  INDEX idx_schedule_due(processed_at,scheduled_at)
);
