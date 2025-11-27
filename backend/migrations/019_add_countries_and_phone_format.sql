-- Migration 019: Ajouter table countries et reformater les numéros de téléphone
-- Objectif: Standardiser les numéros en format +PAYS+NUMERO (ex: +221771234567)

-- 1. Créer la table des pays avec indicatifs
CREATE TABLE IF NOT EXISTS countries (
  id SERIAL PRIMARY KEY,
  code VARCHAR(3) UNIQUE NOT NULL,  -- Ex: '221' pour Sénégal
  country_name VARCHAR(100) NOT NULL,  -- Ex: 'Sénégal'
  flag_emoji VARCHAR(10),  -- Ex: '🇸🇳'
  created_at TIMESTAMP DEFAULT NOW()
);

-- 2. Insérer les pays principaux (Afrique de l'Ouest)
INSERT INTO countries (code, country_name, flag_emoji) VALUES
  ('221', 'Sénégal', '🇸🇳'),
  ('237', 'Cameroun', '🇨🇲'),
  ('233', 'Ghana', '🇬🇭'),
  ('234', 'Nigeria', '🇳🇬'),
  ('225', 'Côte d''Ivoire', '🇨🇮'),
  ('212', 'Maroc', '🇲🇦'),
  ('216', 'Tunisie', '🇹🇳'),
  ('213', 'Algérie', '🇩🇿'),
  ('254', 'Kenya', '🇰🇪'),
  ('255', 'Tanzanie', '🇹🇿'),
  ('256', 'Ouganda', '🇺🇬'),
  ('27', 'Afrique du Sud', '🇿🇦'),
  ('260', 'Zambie', '🇿🇲'),
  ('263', 'Zimbabwe', '🇿🇼'),
  ('266', 'Lesotho', '🇱🇸'),
  ('267', 'Botswana', '🇧🇼'),
  ('268', 'Eswatini', '🇸🇿')
ON CONFLICT DO NOTHING;

-- 3. Ajouter country_code à la table owners si absent
ALTER TABLE owners ADD COLUMN IF NOT EXISTS country_code VARCHAR(3);

-- 4. Ajouter country_code à la table clients si absent
ALTER TABLE clients ADD COLUMN IF NOT EXISTS country_code VARCHAR(3);

-- 5. Fonction pour formater un numéro complet (+PAYS+NUMERO)
CREATE OR REPLACE FUNCTION format_phone_with_country(country_code VARCHAR(3), phone_number TEXT) RETURNS TEXT AS $$
DECLARE
  normalized_phone TEXT;
BEGIN
  -- Normaliser le numéro (garder seulement les chiffres)
  normalized_phone := regexp_replace(phone_number, '[^0-9]', '', 'g');
  
  -- Retourner au format +PAYS+NUMERO
  IF country_code IS NOT NULL AND normalized_phone IS NOT NULL THEN
    RETURN '+' || country_code || normalized_phone;
  END IF;
  
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- 6. Créer un index sur country_code pour les lookups rapides
CREATE INDEX IF NOT EXISTS idx_owners_country_code ON owners(country_code);
CREATE INDEX IF NOT EXISTS idx_clients_country_code ON clients(country_code);

-- 7. Mettre à jour les numéros existants si nécessaire
-- Cette requête suppose que les numéros commencent déjà par +PAYS (ex: +237600000000)
-- Si ce n'est pas le cas, la migration manuelle sera nécessaire
UPDATE owners 
SET country_code = SUBSTRING(phone, 2, 3)
WHERE country_code IS NULL AND phone LIKE '+%';

UPDATE clients 
SET country_code = SUBSTRING(client_number, 2, 3)
WHERE country_code IS NULL AND client_number LIKE '+%';
