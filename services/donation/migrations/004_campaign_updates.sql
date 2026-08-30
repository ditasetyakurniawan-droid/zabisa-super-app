CREATE TABLE IF NOT EXISTS campaign_updates (
  id CHAR(36) PRIMARY KEY,
  campaign_id CHAR(36) NOT NULL,
  title VARCHAR(220) NOT NULL,
  body TEXT NOT NULL,
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  INDEX idx_campaign_updates_campaign(campaign_id,created_at),
  CONSTRAINT fk_campaign_update_campaign FOREIGN KEY(campaign_id) REFERENCES campaigns(id)
);
