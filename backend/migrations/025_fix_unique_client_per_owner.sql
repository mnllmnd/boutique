-- ✅ Migration 025: Corriger la contrainte UNIQUE pour permettre les clients sans numéro
-- Problème: La contrainte UNIQUE sur (client_number, owner_phone) empêche 
-- la création de plusieurs clients sans numéro pour le même propriétaire
-- Car PostgreSQL traite les NULLs différemment dans les UNIQUE constraints

-- Supprimer l'ancienne contrainte
ALTER TABLE clients DROP CONSTRAINT IF EXISTS unique_client_per_owner;

-- Créer une nouvelle contrainte qui n'applique que si client_number N'EST PAS NULL
CREATE UNIQUE INDEX IF NOT EXISTS idx_unique_client_per_owner_not_null 
ON clients(client_number, owner_phone) 
WHERE client_number IS NOT NULL;

-- Cette approche permet:
-- - (client_number='77123', owner='221...') - UNIQUE
-- - (NULL, owner='221...') - MULTIPLE ALLOWED ✅
-- - (NULL, owner='221...') - MULTIPLE ALLOWED ✅
