# ✅ Fonctionnalité : Affichage du nom du créancier pour les clients

## Problème
Quand un client reçoit une dette créée par un propriétaire de boutique, il ne voit que le phone du créancier, pas le nom de sa boutique.

## Solution complète

### 1. Base de données (Migrations)

#### Migration 015_add_creditor_name.sql
```sql
ALTER TABLE debts ADD COLUMN IF NOT EXISTS creditor_name TEXT;
```
- Ajoute une colonne `creditor_name` à la table `debts`
- Permet de stocker le nom du créancier (shop_name)

#### Migration 016_populate_creditor_names.sql
```sql
UPDATE debts d
SET creditor_name = COALESCE(o.shop_name, d.creditor)
FROM owners o
WHERE d.creditor_name IS NULL 
  AND d.creditor = o.phone;
```
- Met à jour les dettes existantes
- Récupère le `shop_name` depuis la table `owners`
- Fallback au phone si pas de shop_name

### 2. Backend (debts.js)

#### POST /loans - Création d'un emprunt
```javascript
// Récupérer le shop_name du propriétaire depuis owners
const ownerRes = await pool.query(
  'SELECT shop_name FROM owners WHERE phone = $1',
  [creditor]
);
const creditorName = ownerRes.rows[0]?.shop_name || creditor;

// Stocker avec creditor_name
INSERT INTO debts (..., creditor_name, ...) 
VALUES (..., $3, ...)  // creditor_name à la position $3
```

#### POST / - Création d'une dette
- Même logique que POST /loans
- Récupère le shop_name depuis owners
- Stocke dans creditor_name

#### GET / et GET /:id
- Retournent déjà `creditor_name` (car SELECT d.* récupère toutes les colonnes)
- Disponible pour l'affichage front-end

### 3. Frontend (main.dart)

#### Logique d'affichage en ligne 2337
```dart
if (clientDebts.isNotEmpty && clientDebts.first['created_by_other'] == true) {
  // C'est une dette créée par un propriétaire pour moi
  clientName = clientDebts.first['creditor_name']?.toString() ?? 
              (fallback au client name);
} else {
  // C'est une dette normale
  clientName = client['name'] ?? fallback;
}
```

**Résultat:** 
- Owner crée une dette pour Client → Client voit le `shop_name` du owner
- Owner voit ses dettes → affiche le `client['name']` comme avant

## Matrice d'affichage

| Scénario | Qui voit | Affiche | Détail |
|----------|----------|---------|--------|
| Owner liste ses prêts | Owner | Client name | Depuis clients.name |
| Client reçoit une dette | Client | Shop name du owner | Depuis debts.creditor_name |
| Client consulte détails | Client | Shop name du owner | Depuis debts.creditor_name |

## Exemple en production

**Avant:**
```
Dettes récentes
┌─────────────────────────────┐
│ 0612345678 (phone number)   │
│ Montant: 5000 XOF           │
└─────────────────────────────┘
```

**Après:**
```
Emprunts récents
┌──────────────────────────────────┐
│ Mon Supermarché (0612345678)     │ ← shop_name + phone
│ Montant: 5000 XOF                │
└──────────────────────────────────┘
```

## Déploiement

1. **Appliquer les migrations en DB:**
   ```bash
   # Migration 015: Ajouter colonne creditor_name
   # Migration 016: Remplir les dettes existantes
   ```

2. **Redémarrer le backend**
   - Les nouvelles dettes auront creditor_name = shop_name

3. **Déployer l'APK/AAB avec les changements main.dart**
   - Affichera le creditor_name pour les dettes reçues (created_by_other)

## Notes techniques

- **Fallback:** Si le shop_name est NULL, utilise le creditor (phone)
- **Compatibilité:** Les anciennes dettes seront mises à jour par migration 016
- **Performance:** Pas d'impact car creditor_name est un simple VARCHAR stocké
- **UX:** Client voit un nom lisible au lieu d'un numéro de téléphone
