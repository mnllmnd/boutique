-- Script d'initialisation de la base de données
CREATE TABLE IF NOT EXISTS debts (
  id SERIAL PRIMARY KEY,
  creditor TEXT NOT NULL,
  debtor TEXT NOT NULL,
  amount NUMERIC(12,2) NOT NULL,
  due_date DATE,
  notes TEXT,
  paid BOOLEAN DEFAULT FALSE,
  paid_at TIMESTAMP,
  created_at TIMESTAMP DEFAULT NOW()
);
