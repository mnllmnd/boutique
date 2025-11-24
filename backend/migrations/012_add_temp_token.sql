-- Add temp_token column for PIN verification
ALTER TABLE owners ADD COLUMN IF NOT EXISTS temp_token VARCHAR(255);
