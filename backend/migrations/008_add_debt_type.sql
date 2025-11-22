-- Migration: Add debt type column to track loans vs regular debts
ALTER TABLE debts ADD COLUMN IF NOT EXISTS type TEXT DEFAULT 'debt' CHECK (type IN ('debt', 'loan'));

-- Create index for faster lookups
CREATE INDEX IF NOT EXISTS idx_debts_type ON debts(type);
