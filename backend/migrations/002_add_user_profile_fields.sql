-- Migration: Add user profile fields
-- Adds first_name, last_name to owners table to support user profile management

BEGIN;

-- Add columns to owners table
ALTER TABLE owners 
ADD COLUMN IF NOT EXISTS first_name VARCHAR(100),
ADD COLUMN IF NOT EXISTS last_name VARCHAR(100);

-- Add updated_at timestamp for tracking changes
ALTER TABLE owners 
ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP DEFAULT NOW();

COMMIT;
