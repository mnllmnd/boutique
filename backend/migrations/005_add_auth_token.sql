-- Migration: Add authentication token system
-- Adds persistent token storage for WhatsApp-like auto-login

BEGIN;

ALTER TABLE owners 
ADD COLUMN IF NOT EXISTS auth_token VARCHAR(255),
ADD COLUMN IF NOT EXISTS token_expires_at TIMESTAMP,
ADD COLUMN IF NOT EXISTS token_created_at TIMESTAMP,
ADD COLUMN IF NOT EXISTS device_id VARCHAR(255),
ADD COLUMN IF NOT EXISTS last_login_at TIMESTAMP;

-- Index for token lookups
CREATE INDEX IF NOT EXISTS idx_owners_auth_token ON owners(auth_token);

COMMIT;
