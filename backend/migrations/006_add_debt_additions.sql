-- Migration: Add debt additions table for tracking additional amounts added to existing debts
CREATE TABLE IF NOT EXISTS debt_additions (
  id SERIAL PRIMARY KEY,
  debt_id INTEGER NOT NULL REFERENCES debts(id) ON DELETE CASCADE,
  amount NUMERIC(12,2) NOT NULL,
  notes TEXT,
  added_at TIMESTAMP NOT NULL DEFAULT NOW(),
  created_at TIMESTAMP DEFAULT NOW()
);

-- Create index for faster lookups
CREATE INDEX IF NOT EXISTS idx_debt_additions_debt_id ON debt_additions(debt_id);
CREATE INDEX IF NOT EXISTS idx_debt_additions_added_at ON debt_additions(added_at);
