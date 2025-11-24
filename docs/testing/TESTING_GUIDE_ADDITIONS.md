# Testing Guide - Debt Additions Feature

## Quick Start

### Prerequisites
- Backend running on `http://localhost:3000`
- Flutter app running or emulator ready
- PostgreSQL database with migrations applied

### Automatic Setup
The migration is automatically applied when the backend starts. Verify with:

```bash
cd backend
npm start
# You should see: "Migrations applied"
```

---

## Backend Testing

### 1. Create a Test Debt (if needed)

```bash
curl -X POST http://localhost:3000/api/debts \
  -H "Content-Type: application/json" \
  -H "x-owner: test_owner" \
  -d '{
    "client_id": 1,
    "amount": 100000,
    "due_date": "2024-12-31",
    "notes": "Test debt"
  }'

# Response: { "id": 42, ... }
# Copy the debt ID for next steps
```

### 2. Test Adding an Amount

```bash
curl -X POST http://localhost:3000/api/debts/42/add \
  -H "Content-Type: application/json" \
  -H "x-owner: test_owner" \
  -d '{
    "amount": 50000,
    "notes": "Client returned with rice purchase"
  }'
```

**Expected Response (201):**
```json
{
  "addition": {
    "id": 1,
    "debt_id": 42,
    "amount": 50000,
    "notes": "Client returned with rice purchase",
    "added_at": "2024-11-20T10:30:00.000Z",
    "created_at": "2024-11-20T10:30:00.000Z"
  },
  "new_debt_amount": 150000
}
```

**Verify in database:**
```sql
SELECT * FROM debt_additions WHERE debt_id = 42;
SELECT amount FROM debts WHERE id = 42;  -- Should be 150000
```

### 3. Test Retrieving Additions

```bash
curl http://localhost:3000/api/debts/42/additions \
  -H "x-owner: test_owner"
```

**Expected Response (200):**
```json
[
  {
    "id": 1,
    "debt_id": 42,
    "amount": 50000,
    "notes": "Client returned with rice purchase",
    "added_at": "2024-11-20T10:30:00.000Z"
  }
]
```

### 4. Test Deleting an Addition

```bash
curl -X DELETE http://localhost:3000/api/debts/42/additions/1 \
  -H "x-owner: test_owner"
```

**Expected Response (200):**
```json
{
  "success": true,
  "new_debt_amount": 100000
}
```

**Verify in database:**
```sql
SELECT COUNT(*) FROM debt_additions WHERE debt_id = 42;  -- Should be 0
SELECT amount FROM debts WHERE id = 42;  -- Should be 100000 again
```

### 5. Test Authorization (Negative Test)

Try accessing with wrong owner:
```bash
curl http://localhost:3000/api/debts/42/additions \
  -H "x-owner: different_owner"

# Should return: 403 Forbidden (Forbidden)
```

### 6. Test with Non-existent Debt

```bash
curl -X POST http://localhost:3000/api/debts/99999/add \
  -H "Content-Type: application/json" \
  -H "x-owner: test_owner" \
  -d '{"amount": 50000}'

# Should return: 404 Not found (Debt not found)
```

---

## Mobile/Flutter Testing

### Test Scenario 1: Add Amount to Existing Debt

1. **Launch app** and login
2. **Navigate to CLIENTS**
3. **Select a client** with at least one debt
4. **Tap on a debt** → Details page opens
5. **Observe:**
   - ✅ "AJOUTER UN MONTANT" button visible (orange)
   - ✅ "HISTORIQUE DES ADDITIONS" section visible (empty if first time)
6. **Click "AJOUTER UN MONTANT"**
7. **Form opens with fields:**
   - ✅ CLIENT name displayed
   - ✅ Current debt amount shown
   - ✅ Amount input field
   - ✅ Date picker (default = today)
   - ✅ Notes text area (optional)
8. **Fill the form:**
   ```
   Amount: 30000
   Date: (keep default or change)
   Notes: "Sugar purchase"
   ```
9. **Tap "AJOUTER LE MONTANT"**
10. **Verify:**
    - ✅ Page returns to debt details
    - ✅ "HISTORIQUE DES ADDITIONS" now shows 1 entry
    - ✅ New amount displayed: original + 30000
    - ✅ Entry shows: "30,000 FCFA | 20/11/2024 10:30" + notes

### Test Scenario 2: Multiple Additions

1. **Repeat the process** 2-3 times with different amounts
2. **Verify:**
   - ✅ Count shows "HISTORIQUE DES ADDITIONS (3)"
   - ✅ All additions listed in reverse chronological order
   - ✅ Total amount = original + sum of all additions

### Test Scenario 3: Payment after Addition

1. **Add an amount** (e.g., +50000)
2. **Click "AJOUTER UN PAIEMENT"**
3. **Pay 80000**
4. **Verify:**
   - ✅ "MONTANT" = original + 50000
   - ✅ "PAYÉ" = 80000 (green)
   - ✅ "RESTE À PAYER" = (original + 50000) - 80000
   - ✅ Progress bar updated

### Test Scenario 4: Date Picker

1. **Open addition form**
2. **Click on DATE field**
3. **Date picker opens**
4. **Select a past date** (e.g., 5 days ago)
5. **Confirm**
6. **Verify:** Selected date appears in the field
7. **Add the amount**
8. **Verify:** Addition shows the past date in history

### Test Scenario 5: Error Handling

**Test 5a: Empty Amount**
1. Leave amount empty
2. Click "AJOUTER LE MONTANT"
3. ✅ Nothing happens (validation prevents)

**Test 5b: Zero or Negative Amount**
1. Enter "0" or "-5000"
2. Click "AJOUTER LE MONTANT"
3. ✅ Shows error dialog "Veuillez entrer un montant valide"

**Test 5c: Network Error**
1. Turn off WiFi/mobile connection
2. Try to add amount
3. ✅ Shows error dialog "Erreur réseau: ..."
4. Turn connection back on and try again
5. ✅ Works normally

**Test 5d: Server Error (Simulate)**
1. Stop backend
2. Try to add amount
3. ✅ Shows network error
4. Start backend
5. ✅ Works again

---

## Database Verification

### Check the Table Schema

```sql
\d debt_additions

-- Expected output:
--  id        | integer | primary key
--  debt_id   | integer | foreign key → debts(id)
--  amount    | numeric | 12,2
--  notes     | text    |
--  added_at  | timestamp | NOT NULL, DEFAULT NOW()
--  created_at | timestamp | DEFAULT NOW()
```

### Verify Data Integrity

```sql
-- Check all additions for a debt
SELECT * FROM debt_additions WHERE debt_id = 42 ORDER BY added_at DESC;

-- Check total amount of a debt (original + additions)
SELECT amount FROM debts WHERE id = 42;

-- Verify foreign key constraint
SELECT d.id, d.amount, COUNT(da.id) as addition_count
FROM debts d
LEFT JOIN debt_additions da ON d.id = da.debt_id
WHERE d.id = 42
GROUP BY d.id;

-- Check activity log
SELECT * FROM activity_log 
WHERE action IN ('debt_addition', 'delete_addition')
ORDER BY created_at DESC
LIMIT 10;
```

### Cascade Delete Test

```sql
-- Delete a debt with additions
DELETE FROM debts WHERE id = 42;

-- Verify additions are automatically deleted (cascade)
SELECT COUNT(*) FROM debt_additions WHERE debt_id = 42;  -- Should return 0
```

---

## Performance Testing

### Load Testing with Multiple Additions

```bash
#!/bin/bash
# Add 100 amounts to same debt
for i in {1..100}; do
  curl -X POST http://localhost:3000/api/debts/42/add \
    -H "Content-Type: application/json" \
    -H "x-owner: test_owner" \
    -d "{\"amount\": $((RANDOM % 100000)), \"notes\": \"Addition $i\"}" \
    -s > /dev/null
done

# Verify retrieval speed
time curl http://localhost:3000/api/debts/42/additions -H "x-owner: test_owner"
```

**Expected:** All 100 additions retrieved in < 500ms

---

## UI Integration Tests

### Test Dark Mode

1. **Enable dark mode** in system settings
2. **Open addition form**
3. ✅ Form elements have dark theme
4. ✅ Text colors are appropriate (readable)
5. ✅ Orange button visible and distinct

### Test Light Mode

1. **Disable dark mode** (light theme)
2. **Open addition form**
3. ✅ Form elements have light theme
4. ✅ All buttons and text readable

### Test Responsiveness

1. **Portrait mode:**
   - ✅ Form fits on screen
   - ✅ All fields accessible

2. **Landscape mode:**
   - ✅ Form still fits
   - ✅ Buttons aligned properly

3. **Tablet (if available):**
   - ✅ Form scales appropriately
   - ✅ Max-width constraint applied (400px)

---

## Localization Check

All visible strings should be in **French**:

- ✅ "AJOUTER UN MONTANT"
- ✅ "MONTANT À AJOUTER"
- ✅ "DATE"
- ✅ "NOTE (OPTIONNEL)"
- ✅ "CLIENT"
- ✅ "MONTANT ACTUEL DE LA DETTE"
- ✅ "HISTORIQUE DES ADDITIONS"
- ✅ "Aucune addition enregistrée"
- ✅ "Veuillez entrer un montant valide"

---

## Regression Testing

**After any code changes, verify:**

1. ✅ Existing debts still work
2. ✅ Existing payments still work
3. ✅ Addition functionality still works
4. ✅ No new errors in console
5. ✅ Database migrations still apply

---

## Common Issues & Solutions

| Issue | Cause | Solution |
|-------|-------|----------|
| "Addition not found" | Wrong addition ID | Verify ID from GET request |
| Debt amount not updated | Migration not applied | Run backend with clean DB |
| Orange button not showing | Flutter cache | `flutter clean` + `flutter pub get` |
| Slow performance | Many additions | Check indices are created |
| 403 Forbidden | Wrong x-owner header | Use correct owner phone |
| Date picker doesn't open | Flutter issue | Update Flutter to latest |

---

## Checklist for Release

- [ ] Backend endpoints tested manually (5 curl requests above)
- [ ] Flutter app tested end-to-end (all scenarios above)
- [ ] Database schema verified
- [ ] Migration runs automatically
- [ ] Dark mode works
- [ ] Light mode works
- [ ] Error messages display correctly
- [ ] Activity log records actions
- [ ] No console errors
- [ ] No lint warnings
- [ ] Documentation complete

---

**Version:** 1.0
**Last Updated:** 20 November 2024
**Tested On:** Flutter 3.x, Node.js 16+, PostgreSQL 12+
