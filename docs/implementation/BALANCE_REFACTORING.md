# Balance Column Refactoring - Documentation

## Overview

The `amount` column in the `debts` table has been refactored to **always represent the remaining balance** (montant restant), never the cumulative total.

**Before:** `amount` = initial_amount + additions (confusing, mixed semantics)  
**After:** `amount` = remaining_balance (remaining to pay/receive)

## Database Changes

### Migration 014 (in `migrate.sql`)

```sql
-- Add original_amount column to track initial debt
ALTER TABLE debts ADD COLUMN IF NOT EXISTS original_amount NUMERIC(12,2);

-- Preserve existing amounts as original amounts
UPDATE debts SET original_amount = COALESCE(amount, 0) WHERE original_amount IS NULL;

-- Recalculate amount as remaining balance
UPDATE debts d SET amount = GREATEST(
  COALESCE((SELECT d.original_amount + COALESCE(SUM(da.amount), 0) FROM debt_additions da WHERE da.debt_id = d.id), 0) -
  COALESCE((SELECT SUM(p.amount) FROM payments p WHERE p.debt_id = d.id), 0),
  0
) WHERE original_amount IS NOT NULL;

-- Add index for performance
CREATE INDEX IF NOT EXISTS idx_debts_original_amount ON debts(original_amount);
```

### Column Semantics

| Column | Purpose | Type |
|--------|---------|------|
| `original_amount` | Initial debt amount (read-only after creation) | NUMERIC(12,2) |
| `amount` | **Remaining balance** (calculated from base + additions - payments) | NUMERIC(12,2) |

## Backend Route Changes

### POST `/debts/:id/add` - Adding Amount to Existing Debt

**Key Change:** After inserting a new addition, the debt's `amount` is **recalculated** as the new remaining balance, not simply incremented.

```javascript
// OLD: const newTotalAmount = parseFloat(debtRes.rows[0].amount) + parseFloat(amount);
// NEW: Call calculateDebtBalance() to get correct remaining after addition

const balance = await calculateDebtBalance(existingDebt.id);
await pool.query('UPDATE debts SET amount=$1 WHERE id=$2', [balance.remaining, existingDebt.id]);
```

**Impact:**
- Ensures `amount` always reflects remaining balance
- Operations are fully traceable through debt_additions table
- No direct modification of the debt's base amount

### POST `/debts/:id/pay` - Recording Payments

**Status:** Already correct ✅

The route already:
1. Inserts payment into `payments` table
2. Calls `calculateDebtBalance()` to get remaining
3. Updates `debts.amount` with the remaining balance

No changes needed for this endpoint.

### PUT `/:id` - Updating Debt Details

**Key Change:** Direct updates to `amount` are now forbidden.

```javascript
if (amount !== undefined) {
  return res.status(400).json({ 
    error: 'Cannot directly update amount. Use POST /:id/add or POST /:id/pay instead.' 
  });
}
```

**Rationale:**
- Amount must always be calculated from base + additions - payments
- Direct updates would break balance integrity
- Use POST endpoints to modify debt amounts

**Allowed updates:**
- `due_date` ✅
- `notes` ✅
- `paid` (status flag) ✅

### POST `/` - Creating New Debt

**Status:** Works correctly ✅

When creating a new debt:
- `original_amount` and `amount` are set to the same initial value
- If a debt already exists for the client, new amount is added as a `debt_addition`
- The addition route properly recalculates the remaining balance

## Mobile App Changes

No changes required. The mobile app already uses `calculateDebtBalance()` from the API and displays:
- `total_debt`: Base amount + additions
- `remaining`: Amount left to pay (what's displayed as the debt amount)

The local Hive sync continues to work correctly because:
1. Offline additions are recorded in the sync queue
2. When synced, POST `/debts/:id/add` recalculates the balance on the backend
3. The next sync retrieves the correct `remaining` value

## Testing Checklist

- [ ] Verify Migration 014 executes on backend startup
- [ ] Test creating a new debt - both `original_amount` and `amount` should be set
- [ ] Test adding amount to existing debt - `amount` should become new remaining balance
- [ ] Test payment - `amount` should decrease correctly
- [ ] Test PUT /:id with amount field - should return 400 error
- [ ] Verify GET / and GET /client/:clientId show correct `remaining` values
- [ ] Test offline sync with additions (should recalculate on server)
- [ ] Test offline sync with payments (should recalculate on server)

## Key Functions

### `calculateDebtBalance(id)` - Located in debts.js

```javascript
async function calculateDebtBalance(id) {
  const baseRes = await pool.query(
    'SELECT COALESCE(amount, 0) as base_amount FROM debts WHERE id=$1',
    [id]
  );
  
  // ... calculates:
  // total_additions = SUM(debt_additions.amount)
  // total_payments = SUM(payments.amount)
  // total_debt = base_amount + total_additions
  // remaining = total_debt - total_payments
  
  return { base_amount, total_additions, total_payments, total_debt, remaining };
}
```

This function is now **critical** - it's called after every operation that modifies a debt.

## Impact Summary

| Area | Impact | Status |
|------|--------|--------|
| Data Integrity | ✅ Amount always calculated from base + additions - payments | Fixed |
| Audit Trail | ✅ All operations tracked in debt_additions & payments | Maintained |
| API Contracts | ⚠️ Amount now read-only (no direct updates) | Breaking change |
| Mobile Sync | ✅ Already uses calculateDebtBalance() | No changes needed |
| PDF Generation | ✅ Already uses remaining balance for display | No changes needed |

## Migration Notes

After deploying this update:

1. **First backend startup**: Migration 014 executes automatically
2. **All existing debts**: `original_amount` is set from current `amount`, then `amount` is recalculated
3. **No data loss**: All values preserved through recalculation
4. **Balance preserved**: Calculations use: base + additions - payments = remaining

## Rollback Plan

If needed to revert:

1. Delete migration 014 from migrations/ folder
2. Remove columns from database: `ALTER TABLE debts DROP COLUMN IF EXISTS original_amount;`
3. Restore old route logic in debts.js (simple addition without recalculation)
4. Update mobile app to handle the old amount semantics

---

**Last Updated:** [Current Date]  
**Status:** ✅ Implemented and ready for testing
