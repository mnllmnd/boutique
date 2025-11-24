-- Migration: Add operation_type to debt_additions for better traceability
-- This allows tracking: addition (for debts), loan_addition (for loans), payment (for both), etc.

-- Add operation_type column if it doesn't exist
ALTER TABLE debt_additions 
ADD COLUMN IF NOT EXISTS operation_type VARCHAR(50) DEFAULT 'addition';

-- Add debt_type column to reference the debt type (debt or loan)
ALTER TABLE debt_additions 
ADD COLUMN IF NOT EXISTS debt_type VARCHAR(50);

-- Create comment explaining operation_type values
-- operation_type values:
--   'addition'      - Additional amount added to a debt (prêt supplémentaire)
--   'loan_addition' - Additional amount borrowed (emprunt supplémentaire)
--   'payment'       - Payment/remboursement made
--   'loan_payment'  - Payment on a loan (remboursement d'emprunt) - for clarity

-- Update existing records to have correct operation_type based on the debt type
UPDATE debt_additions da
SET debt_type = d.type,
    operation_type = CASE 
      WHEN d.type = 'loan' THEN 'loan_addition'
      ELSE 'addition'
    END
FROM debts d
WHERE da.debt_id = d.id AND da.operation_type = 'addition';

-- Add index on operation_type for filtering
CREATE INDEX IF NOT EXISTS idx_debt_additions_operation_type ON debt_additions(operation_type);
CREATE INDEX IF NOT EXISTS idx_debt_additions_debt_type ON debt_additions(debt_type);
