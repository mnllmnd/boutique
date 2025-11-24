# 404 Error Fix - Missing API Endpoints

## Problem
The frontend was getting 404 errors for missing endpoints:
- `GET /api/debt-additions?owner_phone=...` → 404
- `GET /api/payments?owner_phone=...` → 404

These endpoints are called by `HiveServiceManager` during Hive data synchronization for offline support.

## Root Cause
The backend had these endpoints nested under debt routes (`/debts/:id/additions`, `/debts/:id/payments`) but the frontend was calling top-level endpoints (`/debt-additions`, `/payments`) with a query parameter `owner_phone`.

## Solution

### Added Two New Endpoints to `backend/index.js`

#### 1. `GET /api/debt-additions?owner_phone=<phone>`
```javascript
app.get('/api/debt-additions', async (req, res) => {
  const ownerPhone = req.query.owner_phone;
  
  // Get all debts for this owner
  const debtsRes = await pool.query(
    'SELECT id FROM debts WHERE creditor=$1',
    [ownerPhone]
  );

  // Get all additions for all these debts
  const additionsRes = await pool.query(
    `SELECT * FROM debt_additions 
     WHERE debt_id = ANY($1)
     ORDER BY added_at DESC`,
    [debtIds]
  );

  res.json(additionsRes.rows);
});
```

**Purpose**: Fetch all debt additions for a specific owner (used by Hive sync)

**Returns**: Array of `debt_additions` records:
```json
[
  {
    "id": 1,
    "debt_id": 5,
    "amount": 5000,
    "added_at": "2024-11-24T10:30:00Z",
    "notes": "Additional amount added"
  }
]
```

#### 2. `GET /api/payments?owner_phone=<phone>`
```javascript
app.get('/api/payments', async (req, res) => {
  const ownerPhone = req.query.owner_phone;
  
  // Get all debts for this owner
  const debtsRes = await pool.query(
    'SELECT id FROM debts WHERE creditor=$1',
    [ownerPhone]
  );

  // Get all payments for all these debts
  const paymentsRes = await pool.query(
    `SELECT * FROM payments 
     WHERE debt_id = ANY($1)
     ORDER BY paid_at DESC`,
    [debtIds]
  );

  res.json(paymentsRes.rows);
});
```

**Purpose**: Fetch all payments for a specific owner (used by Hive sync)

**Returns**: Array of `payments` records:
```json
[
  {
    "id": 1,
    "debt_id": 5,
    "amount": 10000,
    "paid_at": "2024-11-24T09:15:00Z",
    "payment_method": "cash",
    "reference": "payment ref"
  }
]
```

## Files Modified

1. **`backend/index.js`**
   - Added `/api/debt-additions` endpoint (lines 24-55)
   - Added `/api/payments` endpoint (lines 57-88)
   - Both endpoints accept `owner_phone` query parameter
   - Both endpoints retrieve all related records for that owner
   - Both return empty array `[]` if owner has no debts

## How It Works

**Endpoint Logic**:
1. Accept `owner_phone` query parameter
2. Find all debts where `creditor = owner_phone`
3. Get all additions/payments for those debts using `ANY(debt_ids)`
4. Return sorted results (newest first)

**Query Strategy**:
- Uses PostgreSQL `ANY()` operator for efficient bulk queries
- Single query per endpoint instead of N+1
- Ordered by timestamp descending (newest first)

## Integration with Hive

These endpoints are called by `HiveServiceManager._fetchAndSync*` methods:

```dart
// In hive_service.dart
Future<void> _fetchAndSyncAdditions(String ownerPhone, Map<String, String> headers) async {
  final response = await http.get(
    Uri.parse('$apiBaseUrl/debt-additions?owner_phone=$ownerPhone'),  // ✅ Now works
    headers: headers,
  );
  // ... process additions
}

Future<void> _fetchAndSyncPayments(String ownerPhone, Map<String, String> headers) async {
  final response = await http.get(
    Uri.parse('$apiBaseUrl/payments?owner_phone=$ownerPhone'),  // ✅ Now works
    headers: headers,
  );
  // ... process payments
}
```

## Testing

To test these endpoints:

```bash
# Test debt-additions
curl "http://localhost:3000/api/debt-additions?owner_phone=784666900"

# Test payments
curl "http://localhost:3000/api/payments?owner_phone=784666900"

# Expected response (200 OK):
[
  { "id": 1, "debt_id": 5, ... },
  { "id": 2, "debt_id": 5, ... }
]

# Expected response (no debts):
[]
```

## Performance Considerations

- **Efficiency**: Uses single `ANY()` query instead of N queries
- **Scalability**: Works with any number of debts/payments
- **Ordering**: Results ordered by timestamp (most recent first)
- **Empty Results**: Returns empty array for owners with no debts
- **Error Handling**: Returns 500 on DB error, 400 if owner_phone missing

## Related Endpoints

| Endpoint | Purpose | Returns |
|----------|---------|---------|
| `GET /api/debt-additions?owner_phone=X` | All additions for owner | Array of additions |
| `GET /api/payments?owner_phone=X` | All payments for owner | Array of payments |
| `GET /api/debts?owner_phone=X` | All debts for owner | Array of debts |
| `GET /api/clients?owner_phone=X` | All clients for owner | Array of clients |
| `GET /api/debts/:id/additions` | Additions for specific debt | Array of additions |
| `GET /api/debts/:id/payments` | Payments for specific debt | Array of payments |

## Summary

✅ Added 2 missing backend endpoints  
✅ Fixed 404 errors for Hive sync  
✅ Enabled offline data synchronization  
✅ Maintains backward compatibility  
✅ Efficient bulk queries using PostgreSQL `ANY()`
