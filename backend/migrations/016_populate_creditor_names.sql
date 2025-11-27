-- ✅ MIGRATION : Mettre à jour les dettes existantes avec le nom du créancier
-- Priorité: shop_name > first_name + last_name > phone

UPDATE debts d
SET creditor_name = COALESCE(
  NULLIF(TRIM(o.shop_name), ''),  -- Si shop_name n'est pas vide
  NULLIF(TRIM(CONCAT(COALESCE(o.first_name, ''), ' ', COALESCE(o.last_name, ''))), ' '),  -- Si first_name + last_name
  d.creditor  -- Sinon le phone
)
FROM owners o
WHERE d.creditor_name IS NULL 
  AND d.creditor = o.phone;
