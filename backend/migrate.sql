-- Migration: add clients and payments tables, add client_id to debts
CREATE TABLE IF NOT EXISTS clients (
  id SERIAL PRIMARY KEY,
  client_number TEXT UNIQUE,
  name TEXT NOT NULL,
  avatar_url TEXT,
  created_at TIMESTAMP DEFAULT NOW()
);

-- Add owner_phone to clients to associate clients with a boutique owner
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='clients' AND column_name='owner_phone') THEN
    ALTER TABLE clients ADD COLUMN owner_phone TEXT;
  END IF;
END$$;

-- Owners table for simple authentication
CREATE TABLE IF NOT EXISTS owners (
  id SERIAL PRIMARY KEY,
  phone TEXT UNIQUE NOT NULL,
  password TEXT,
  pin VARCHAR(255),
  shop_name TEXT,
  first_name TEXT,
  last_name TEXT,
  auth_token TEXT,
  token_expires_at TIMESTAMP,
  token_created_at TIMESTAMP,
  device_id TEXT,
  last_login_at TIMESTAMP,
  boutique_mode_enabled BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS payments (
  id SERIAL PRIMARY KEY,
  debt_id INTEGER REFERENCES debts(id) ON DELETE CASCADE,
  amount NUMERIC(12,2) NOT NULL,
  paid_at TIMESTAMP NOT NULL,
  notes TEXT
);

-- Add client_id to debts if not present
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='debts' AND column_name='client_id') THEN
    ALTER TABLE debts ADD COLUMN client_id INTEGER REFERENCES clients(id);
  END IF;
END$$;

-- Add paid and paid_at if missing (safe no-op if already exists)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='debts' AND column_name='paid') THEN
    ALTER TABLE debts ADD COLUMN paid BOOLEAN DEFAULT FALSE;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='debts' AND column_name='paid_at') THEN
    ALTER TABLE debts ADD COLUMN paid_at TIMESTAMP;
  END IF;
END$$;

-- Create index to speed up lookups
CREATE INDEX IF NOT EXISTS idx_debts_client_id ON debts(client_id);
ALTER TABLE debts ADD COLUMN IF NOT EXISTS paid BOOLEAN DEFAULT FALSE; 
ALTER TABLE debts ADD COLUMN IF NOT EXISTS paid_at TIMESTAMP; 
 
-- Users and team membership for shops
CREATE TABLE IF NOT EXISTS users (
  id SERIAL PRIMARY KEY,
  phone TEXT UNIQUE,
  name TEXT,
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS shop_users (
  owner_phone TEXT NOT NULL,
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  role TEXT DEFAULT 'clerk',
  added_at TIMESTAMP DEFAULT NOW(),
  PRIMARY KEY (owner_phone, user_id)
);

-- Activity log for shop actions
CREATE TABLE IF NOT EXISTS activity_log (
  id SERIAL PRIMARY KEY,
  owner_phone TEXT NOT NULL,
  user_id INTEGER,
  action TEXT NOT NULL,
  details JSONB,
  created_at TIMESTAMP DEFAULT NOW()
);

-- Expand PIN column to store hashed PINs (bcrypt produces ~60 char hashes)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='owners' AND column_name='pin' AND data_type='character varying') THEN
    -- Check current length
    ALTER TABLE owners ALTER COLUMN pin TYPE VARCHAR(255);
  END IF;
END$$;

-- Add temp_token column for PIN verification
ALTER TABLE owners ADD COLUMN IF NOT EXISTS temp_token VARCHAR(255);

-- ✅ Migration 012: Add operation_type to debt_additions for better traceability
ALTER TABLE debt_additions 
ADD COLUMN IF NOT EXISTS operation_type VARCHAR(50) DEFAULT 'addition';

ALTER TABLE debt_additions 
ADD COLUMN IF NOT EXISTS debt_type VARCHAR(50);

-- Update existing records to have correct operation_type based on the debt type
UPDATE debt_additions da
SET debt_type = d.type,
    operation_type = CASE 
      WHEN d.type = 'loan' THEN 'loan_addition'
      ELSE 'addition'
    END
FROM debts d
WHERE da.debt_id = d.id AND da.operation_type = 'addition';

CREATE INDEX IF NOT EXISTS idx_debt_additions_operation_type ON debt_additions(operation_type);
CREATE INDEX IF NOT EXISTS idx_debt_additions_debt_type ON debt_additions(debt_type);

-- ✅ Migration 013: Add operation_type and debt_type to payments table for better traceability
ALTER TABLE payments 
ADD COLUMN IF NOT EXISTS operation_type VARCHAR(50) DEFAULT 'payment';

ALTER TABLE payments 
ADD COLUMN IF NOT EXISTS debt_type VARCHAR(50);

-- Update existing records to have correct operation_type based on the debt type
UPDATE payments p
SET debt_type = d.type,
    operation_type = CASE 
      WHEN d.type = 'loan' THEN 'loan_payment'
      ELSE 'payment'
    END
FROM debts d
WHERE p.debt_id = d.id AND p.operation_type = 'payment';

CREATE INDEX IF NOT EXISTS idx_payments_operation_type ON payments(operation_type);
CREATE INDEX IF NOT EXISTS idx_payments_debt_type ON payments(debt_type);

-- ✅ Migration 014: Restructure debts table - amount should always be remaining balance
-- Add original_amount column to track initial debt amount
ALTER TABLE debts ADD COLUMN IF NOT EXISTS original_amount NUMERIC(12,2);

-- Set original_amount from current amount for existing debts
UPDATE debts 
SET original_amount = COALESCE(amount, 0)
WHERE original_amount IS NULL;

-- Recalculate amount as remaining balance for existing debts
UPDATE debts d
SET amount = GREATEST(
  COALESCE((SELECT d.original_amount + COALESCE(SUM(da.amount), 0) FROM debt_additions da WHERE da.debt_id = d.id), 0) -
  COALESCE((SELECT SUM(p.amount) FROM payments p WHERE p.debt_id = d.id), 0),
  0
)
WHERE original_amount IS NOT NULL;

-- From now on:
-- - original_amount = initial debt amount (never changes)
-- - amount = remaining balance (decreases as payments are made, increases if additions are made)
-- - Use calculateDebtBalance() function to get total, additions, payments

CREATE INDEX IF NOT EXISTS idx_debts_original_amount ON debts(original_amount);