-- ✅ NOUVELLE MIGRATION : Ajouter le nom du créancier aux dettes
-- Permet au client de voir le nom du propriétaire/créancier qui lui a créé la dette

ALTER TABLE debts ADD COLUMN IF NOT EXISTS creditor_name TEXT;
