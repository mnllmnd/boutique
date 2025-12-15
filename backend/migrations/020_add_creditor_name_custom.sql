-- Migration 020: Ajouter creditor_name_custom pour persister le nom du contact personnalisé
-- Objectif: Quand on ajoute un créancier comme contact avec un nom personnalisé,
-- stocker ce nom dans la dette pour qu'il s'affiche partout

ALTER TABLE debts ADD COLUMN IF NOT EXISTS creditor_name_custom TEXT;

-- Indexer cette colonne pour les requêtes rapides
CREATE INDEX IF NOT EXISTS idx_debts_creditor_name_custom ON debts(creditor_name_custom);
