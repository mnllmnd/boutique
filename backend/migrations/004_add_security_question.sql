-- Migration: Add security question feature
-- Adds security question and answer for password recovery

BEGIN;

ALTER TABLE owners 
ADD COLUMN IF NOT EXISTS security_question VARCHAR(255),
ADD COLUMN IF NOT EXISTS security_answer_hash VARCHAR(255);

COMMIT;
