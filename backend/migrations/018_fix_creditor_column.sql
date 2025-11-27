-- Migration 018: Agrandir colonne creditor et ajouter normalized_creditor
-- Problème: creditor varchar(20) était trop petit pour les numéros de téléphone

-- 1. Augmenter la taille de creditor
ALTER TABLE debts ALTER COLUMN creditor TYPE text;

-- 2. Ajouter une colonne pour stocker le numéro normalisé du créancier
ALTER TABLE debts ADD COLUMN IF NOT EXISTS normalized_creditor TEXT;

-- 3. Fonction pour normaliser les numéros (si elle n'existe pas déjà)
CREATE OR REPLACE FUNCTION normalize_phone(phone TEXT) RETURNS TEXT AS $$
BEGIN
  RETURN regexp_replace(phone, '[^0-9]', '', 'g');
END;
$$ LANGUAGE plpgsql;

-- 4. Remplir normalized_creditor pour les enregistrements existants
UPDATE debts 
SET normalized_creditor = normalize_phone(creditor)
WHERE normalized_creditor IS NULL AND creditor IS NOT NULL;

-- 5. Créer un index sur normalized_creditor pour les recherches
CREATE INDEX IF NOT EXISTS idx_debts_normalized_creditor ON debts(normalized_creditor);

-- 6. Créer un trigger pour normaliser automatiquement creditor à l'insertion/mise à jour
CREATE OR REPLACE FUNCTION debts_normalize_creditor() RETURNS TRIGGER AS $$
BEGIN
  NEW.normalized_creditor := normalize_phone(NEW.creditor);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS debts_before_insert_normalize_creditor ON debts;
DROP TRIGGER IF EXISTS debts_before_update_normalize_creditor ON debts;

CREATE TRIGGER debts_before_insert_normalize_creditor
BEFORE INSERT ON debts
FOR EACH ROW
EXECUTE FUNCTION debts_normalize_creditor();

CREATE TRIGGER debts_before_update_normalize_creditor
BEFORE UPDATE ON debts
FOR EACH ROW
EXECUTE FUNCTION debts_normalize_creditor();
