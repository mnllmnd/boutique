-- Migration: Add operation_type and debt_type to payments table for better traceability
-- This tracks whether a payment was for a debt (prêt) or a loan (emprunt)

-- Add operation_type column if it doesn't exist
ALTER TABLE payments 
ADD COLUMN IF NOT EXISTS operation_type VARCHAR(50) DEFAULT 'payment';

-- Add debt_type column to reference the debt type (debt or loan)
ALTER TABLE payments 
ADD COLUMN IF NOT EXISTS debt_type VARCHAR(50);

-- Create comment explaining operation_type values
-- operation_type values:
--   'payment'       - Payment received (paiement reçu for debt/prêt)
--   'loan_payment'  - Payment on a loan (remboursement d'emprunt)

-- Update existing records to have correct operation_type based on the debt type
UPDATE payments p
SET debt_type = d.type,
    operation_type = CASE 
      WHEN d.type = 'loan' THEN 'loan_payment'
      ELSE 'payment'
    END
FROM debts d
WHERE p.debt_id = d.id AND p.operation_type = 'payment';

-- Add index on operation_type for filtering
CREATE INDEX IF NOT EXISTS idx_payments_operation_type ON payments(operation_type);
CREATE INDEX IF NOT EXISTS idx_payments_debt_type ON payments(debt_type);
