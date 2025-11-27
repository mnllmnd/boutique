# ✅ Mise à jour du contrôle d'accès - Client Access Support

## Changements appliqués

### 1. Routes debts.js - 5 routes modifiées pour supporter `client_number`

#### POST `/:id/pay` (Ajouter un paiement)
**Avant:** Seul le créancier pouvait faire un paiement
```sql
SELECT creditor, type FROM debts WHERE id=$1
if (debtRes.rows[0].creditor !== owner) return 403
```

**Après:** Creditor OU Client (via client_number) peuvent payer
```sql
SELECT d.* FROM debts d
LEFT JOIN clients c ON d.client_id = c.id
WHERE d.id = $1 AND (d.creditor = $2 OR c.client_number = $2)
```

#### GET `/:id/payments`
**Avant:** Seul le créancier pouvait voir les paiements
```sql
SELECT creditor FROM debts WHERE id=$1
if (debtRes.rows[0].creditor !== owner) return 403
```

**Après:** Creditor OU Client (via client_number) peuvent voir
```sql
SELECT d.* FROM debts d
LEFT JOIN clients c ON d.client_id = c.id
WHERE d.id = $1 AND (d.creditor = $2 OR c.client_number = $2)
```

#### GET `/:id/additions`
**Avant:** Seul le créancier pouvait voir les additions
```sql
SELECT creditor FROM debts WHERE id=$1
if (debtRes.rows[0].creditor !== owner) return 403
```

**Après:** Creditor OU Client (via client_number) peuvent voir
```sql
SELECT d.* FROM debts d
LEFT JOIN clients c ON d.client_id = c.id
WHERE d.id = $1 AND (d.creditor = $2 OR c.client_number = $2)
```

#### POST `/:id/disputes`
**Avant:** Accès non vérifié correctement
```sql
SELECT * FROM debts WHERE id=$1
```

**Après:** Creditor OU Client (via client_number) peuvent créer une dispute
```sql
SELECT d.* FROM debts d
LEFT JOIN clients c ON d.client_id = c.id
WHERE d.id = $1 AND (d.creditor = $2 OR c.client_number = $2)
```

#### GET `/:id/disputes`
**Avant:** Vérification directe sur client_id (INTEGER) qui échouait
```sql
SELECT * FROM debts WHERE id=$1
if (debt.creditor !== owner && debt.client_id !== owner) return 403
```

**Après:** Creditor OU Client (via client_number) peuvent voir les disputes
```sql
SELECT d.* FROM debts d
LEFT JOIN clients c ON d.client_id = c.id
WHERE d.id = $1 AND (d.creditor = $2 OR c.client_number = $2)
```

### 2. Route clients.js - GET `/:id` modifiée

**Avant:**
```sql
SELECT * FROM clients WHERE id=$1 AND owner_phone = $2
```

**Après:** Propriétaire OU le client lui-même
```sql
SELECT * FROM clients WHERE id=$1 AND (owner_phone = $2 OR client_number = $2)
```

### 3. Route clients.js - GET `/:id/debts` modifiée

**Avant:**
```sql
SELECT id FROM clients WHERE id=$1 AND owner_phone=$2
SELECT * FROM debts WHERE client_id=$1 AND creditor=$2
```

**Après:** Propriétaire OU le client, retourne TOUTES les dettes (pas seulement celles du propriétaire)
```sql
SELECT id FROM clients WHERE id=$1 AND (owner_phone=$2 OR client_number=$2)
SELECT * FROM debts WHERE client_id=$1  // Sans filtre creditor
```

**+ Type Inversion Logic:** Les dettes inversent leur type si le client les consulte (debt ↔ loan)

## Matrice d'accès resultante

| Endpoint | Owner | Client | Remarques |
|----------|-------|--------|-----------|
| GET `/debts` | ✅ | ✅ | Voir toutes ses dettes (créées par lui ou pour lui) |
| GET `/debts/:id` | ✅ | ✅ | Voir détails de sa dette |
| POST `/debts/:id/pay` | ✅ | ✅ | **FIXED** - Client peut maintenant payer sa dette |
| GET `/debts/:id/payments` | ✅ | ✅ | **FIXED** - Client peut voir les paiements |
| POST `/debts/:id/add` | ✅ | ❌ | Seul owner peut ajouter des frais/intérêts |
| GET `/debts/:id/additions` | ✅ | ✅ | **FIXED** - Client peut voir les additions |
| DELETE `/debts/:id/additions/:additionId` | ✅ | ❌ | Seul owner peut supprimer |
| POST `/debts/:id/disputes` | ❌ | ✅ | Client conteste, owner ne peut pas contester sa propre dette |
| GET `/debts/:id/disputes` | ✅ | ✅ | **FIXED** - Les deux parties voient les contestations |
| PATCH `/debts/:id/disputes/:disputeId/resolve` | ✅ | ❌ | Seul owner (créancier) peut résoudre |
| GET `/clients/:id` | ✅ | ✅ | **FIXED** - Client voit ses propres infos |
| GET `/clients/:id/debts` | ✅ | ✅ | **FIXED** - Client voit toutes ses dettes |

## Erreurs résolvées

### ✅ 404 Not Found: `/api/clients/31`
- **Cause:** Route `/clients/:id` vérifiait uniquement `owner_phone`
- **Fix:** Maintenant accepte `owner_phone` OU `client_number`

### ✅ 403 Forbidden: `/api/debts/23/payments`
- **Cause:** Route `/debts/:id/payments` vérifiait uniquement `creditor`
- **Fix:** Maintenant accepte creditor OU client_number via LEFT JOIN

### ✅ 403 Forbidden: `/api/debts/23/additions`
- **Cause:** Route `/debts/:id/additions` vérifiait uniquement `creditor`
- **Fix:** Maintenant accepte creditor OU client_number via LEFT JOIN

### ✅ 403 Forbidden: `/api/debts/23/disputes`
- **Cause:** Route GET `/debts/:id/disputes` vérifiait `client_id` (INTEGER) au lieu de `client_number`
- **Fix:** Utilise LEFT JOIN clients et compare `client_number` (VARCHAR)

## Instructions de test

1. **Créer deux comptes**
   - Compte A (Boutique Owner): `owner_phone = "0612345678"`
   - Compte B (Client): `client_number = "0687654321"`

2. **Owner crée une dette pour Client**
   ```
   POST /api/debts
   x-owner: "0612345678"
   {
     "creditor": "0612345678",
     "client_id": 31,  // ID du client
     "amount": 5000,
     "type": "debt"
   }
   ```

3. **Client se connecte et teste l'accès**
   ```
   x-owner: "0687654321"  // client_number du client
   
   GET /api/clients/31          // Devrait 200 (ses propres infos)
   GET /api/debts/23           // Devrait 200 (sa dette)
   GET /api/debts/23/payments  // Devrait 200 ✅ FIXED
   GET /api/debts/23/additions // Devrait 200 ✅ FIXED
   GET /api/debts/23/disputes  // Devrait 200 ✅ FIXED
   
   POST /api/debts/23/disputes // Devrait 201 (créer une contestation)
   {
     "reason": "Montant incorrect",
     "message": "La facture était pour 3000 pas 5000"
   }
   ```

4. **Vérifier type inversion**
   - Owner voit: type="debt" → "prêt"
   - Client voit: type="debt" → affiche comme "emprunt" (inversé)
