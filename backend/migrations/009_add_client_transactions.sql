-- Migration: add client_transactions table and client balance column
CREATE TABLE IF NOT EXISTS client_transactions (
  id SERIAL PRIMARY KEY,
  client_id INTEGER REFERENCES clients(id) ON DELETE CASCADE,
  owner_phone TEXT NOT NULL,
  type TEXT NOT NULL, -- 'debt' | 'payment' | 'addition' | 'loan'
  amount NUMERIC(12,2) NOT NULL,
  amount_signed NUMERIC(12,2) NOT NULL, -- positive for debts/additions, negative for payments
  related_debt_id INTEGER REFERENCES debts(id),
  notes TEXT,
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_client_transactions_client_id ON client_transactions(client_id);
CREATE INDEX IF NOT EXISTS idx_client_transactions_created_at ON client_transactions(created_at);

-- Add a balance column to clients for fast reads (kept in sync when transactions are created)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='clients' AND column_name='balance') THEN
    ALTER TABLE clients ADD COLUMN balance NUMERIC(12,2) DEFAULT 0;
  END IF;
END$$;
