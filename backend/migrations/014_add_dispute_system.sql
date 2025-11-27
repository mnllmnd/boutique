-- ✅ NOUVELLE MIGRATION : Système de contestation des dettes
-- Permet à l'utilisateur B de contester une dette créée par l'utilisateur A

-- 1. Ajouter les colonnes de suivi à la table debts
ALTER TABLE debts ADD COLUMN IF NOT EXISTS created_by TEXT;
ALTER TABLE debts ADD COLUMN IF NOT EXISTS dispute_status TEXT DEFAULT 'none';

-- 2. Créer la table debt_disputes pour tracer les contestations
CREATE TABLE IF NOT EXISTS debt_disputes (
  id SERIAL PRIMARY KEY,
  debt_id INTEGER NOT NULL REFERENCES debts(id) ON DELETE CASCADE,
  disputed_by TEXT NOT NULL,
  reason TEXT NOT NULL,
  message TEXT,
  created_at TIMESTAMP DEFAULT NOW(),
  resolved_at TIMESTAMP,
  resolution_note TEXT
);

-- 3. Index pour les requêtes rapides
CREATE INDEX IF NOT EXISTS idx_debt_disputes_debt_id ON debt_disputes(debt_id);
CREATE INDEX IF NOT EXISTS idx_debt_disputes_disputed_by ON debt_disputes(disputed_by);
CREATE INDEX IF NOT EXISTS idx_debts_dispute_status ON debts(dispute_status);
CREATE INDEX IF NOT EXISTS idx_debts_created_by ON debts(created_by);
