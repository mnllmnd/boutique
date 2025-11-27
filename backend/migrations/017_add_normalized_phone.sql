-- ✅ Migration 017: Ajouter support pour normalisation de numéros de téléphone
-- Cela améliore le matching automatique entre clients avec des numéros similaires

-- Ajouter une colonne pour stocker le numéro normalisé
ALTER TABLE clients ADD COLUMN IF NOT EXISTS normalized_phone TEXT;

-- Fonction pour normaliser un numéro (supprimer espaces, tirets, parenthèses, etc.)
CREATE OR REPLACE FUNCTION normalize_phone(phone TEXT) RETURNS TEXT AS $$
BEGIN
  -- Supprimer tous les caractères non numériques sauf le + au début
  RETURN regexp_replace(phone, '[^0-9]', '', 'g');
END;
$$ LANGUAGE plpgsql;

-- Normaliser les numéros existants
UPDATE clients 
SET normalized_phone = normalize_phone(client_number)
WHERE normalized_phone IS NULL AND client_number IS NOT NULL;

-- Créer un index composite pour optimiser le matching
CREATE INDEX IF NOT EXISTS idx_clients_owner_normalized_phone 
ON clients(owner_phone, normalized_phone) 
WHERE normalized_phone IS NOT NULL;

-- Créer un unique index pour empêcher les doublons (par propriétaire + numéro normalisé)
CREATE UNIQUE INDEX IF NOT EXISTS idx_clients_unique_normalized 
ON clients(owner_phone, normalized_phone) 
WHERE normalized_phone IS NOT NULL;

-- Trigger automatique pour normaliser les numéros à l'insertion/mise à jour
CREATE OR REPLACE FUNCTION clients_normalize_phone() RETURNS TRIGGER AS $$
BEGIN
  NEW.normalized_phone := normalize_phone(NEW.client_number);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS clients_before_insert_normalize ON clients;
DROP TRIGGER IF EXISTS clients_before_update_normalize ON clients;

CREATE TRIGGER clients_before_insert_normalize
BEFORE INSERT ON clients
FOR EACH ROW
EXECUTE FUNCTION clients_normalize_phone();

CREATE TRIGGER clients_before_update_normalize
BEFORE UPDATE ON clients
FOR EACH ROW
EXECUTE FUNCTION clients_normalize_phone();
