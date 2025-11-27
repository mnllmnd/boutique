# 📱 Système de Réception de Dettes - Guide Utilisateur

## Comment l'Utilisateur B Reçoit la Dette

### Flux Complet

```
Utilisateur A (Ahmed)        →  Crée une dette  →  Utilisateur B (Aziz)
                                 5000 F
```

### 1️⃣ **Ahmed crée une dette pour Aziz**
- Ahmed ouvre l'app
- Clique sur "+ Ajouter une dette"
- Cherche Aziz
- Entre le montant: 5000 F
- Confirme

### 2️⃣ **Aziz reçoit la dette automatiquement**
- Aziz ouvre l'app
- La dette apparaît immédiatement dans sa liste (elle n'était pas là avant)
- Le badge s'affiche sur la liste
- **Alerte orange** en haut: "Cette dette a été créée par quelqu'un d'autre"

### 3️⃣ **Aziz peut contester**
- Aziz clique sur la dette
- Voit l'alerte orange
- Clique sur "CONTESTER CETTE DETTE"
- Remplit le formulaire:
  - Raison: "Montant incorrect"
  - Message: "Ahmed m'a dit 3000 F pas 5000 F"
- La contestation est enregistrée

### 4️⃣ **Ahmed voit la contestation**
- Ahmed revient sur la même dette
- Voit le badge: "⚠️ 1 contestation en attente"
- Ouvre la section CONTESTATIONS
- Voit le détail de la contestation
- Peut répondre avec une note de résolution

## Identité de l'Utilisateur - Comment ça Marche

### Système d'Identification

```
Header HTTP: x-owner
   ↓
  user_phone ou username
   ↓
Utilisé pour:
  - Identifier qui crée une dette
  - Savoir qui est le créancier
  - Savoir qui est le débiteur
```

### Exemple Concret

**Ahmed** (créancier):
```
x-owner: 225534567890  (téléphone d'Ahmed)
→ Ahmed crée une dette pour Aziz
→ Enregistré: creditor=225534567890, client_id=Aziz, created_by=225534567890
```

**Aziz** (débiteur):
```
x-owner: 225587654321  (téléphone d'Aziz)
→ Aziz se connecte
→ Flask voit: x-owner=225587654321
→ Récupère TOUTES les dettes où:
   - creditor=225587654321 (dettes qu'Aziz a créées)
   OU
   - client_id=225587654321 (dettes créées pour Aziz)
→ Aziz voit les deux!
```

## Backend - Comment c'est Implémenté

### Route GET /debts
```javascript
SELECT * FROM debts 
WHERE creditor=$1    // Dettes que JE ai créées
   OR client_id=$2   // Dettes créées POUR MOI
ORDER BY id DESC
```

### Route GET /debts/:id
```javascript
SELECT * FROM debts 
WHERE id=$1 
  AND (creditor=$2 OR client_id=$2)
```

**Résultat**: L'utilisateur peut voir la dette s'il est:
- ✅ Le créancier (celui qui a créé la dette)
- ✅ Le débiteur (celui pour qui elle a été créée)
- ❌ Personne d'autre

### Flags d'Identification

Chaque dette retourne:
```json
{
  "id": 123,
  "creditor": "225534567890",
  "client_id": "Aziz",
  "created_by": "225534567890",
  "created_by_me": false,      // Aziz n'a pas créé cette dette
  "created_by_other": true,    // Quelqu'un d'autre l'a créée
  "amount": 5000,
  "dispute_status": "none"
}
```

## Frontend - Indicateurs Visuels

### Sur la Page Principale (Liste)
```
┌─────────────────────┐
│ Aziz                │
│ 5000 F              │
│ ⚠️ Créée par Ahmed  │ ← Badge orange si créée par autre
└─────────────────────┘
```

### Sur la Page de Détails
```
┌────────────────────────────────┐
│ ⚠️ Cette dette a été créée      │ ← Alerte prominente
│    par quelqu'un d'autre       │
│    Vous pouvez la contester    │
└────────────────────────────────┘

AZIZ
contact

Aziz vous doit
5000 F ────────────

[CONTESTER CETTE DETTE] ← Bouton accessible
```

## Bases de Données

### Migration: 014_add_dispute_system.sql

**Ajouts:**
```sql
ALTER TABLE debts ADD COLUMN created_by TEXT;
ALTER TABLE debts ADD COLUMN dispute_status TEXT DEFAULT 'none';

CREATE TABLE debt_disputes (
  id SERIAL PRIMARY KEY,
  debt_id INTEGER,
  disputed_by TEXT,
  reason TEXT,
  message TEXT,
  created_at TIMESTAMP DEFAULT NOW(),
  resolved_at TIMESTAMP,
  resolution_note TEXT
);
```

### Index Critiques
```sql
CREATE INDEX idx_debts_client_id ON debts(client_id);
CREATE INDEX idx_debts_creditor ON debts(creditor);
CREATE INDEX idx_debt_disputes_disputed_by ON debt_disputes(disputed_by);
CREATE INDEX idx_debts_dispute_status ON debts(dispute_status);
```

## Scénarios de Test

### Test 1: Créer une dette pour quelqu'un d'autre
```
1. Compte Ahmed (225534567890)
   → Crée une dette "Aziz doit 5000 F"
   
2. Compte Aziz (225587654321)
   → Ouvre l'app
   → ✅ Voit la dette dans la liste
   → ✅ Voit l'alerte orange
   → ✅ Peut contester
   → ✅ Voit "Créée par Ahmed"
```

### Test 2: Contester une dette
```
1. Aziz clique sur la dette
2. Clique "CONTESTER CETTE DETTE"
3. Remplit: Raison="Erreur" + Message="C'est pas moi"
4. Ahmed retourne sur la dette
5. ✅ Voit le badge "⚠️ 1 contestation"
6. ✅ Voit le détail de la contestation
```

### Test 3: Résoudre une contestation
```
1. Ahmed clique sur la contestation
2. Fournit une note: "Confirmé, c'est une erreur. Suppression en cours."
3. ✅ Aziz voit: "Contestation résolue"
4. ✅ L'historique reste visible
```

## Sécurité & Permissions

### Qui peut voir une dette?
- ✅ Le créancier (creditor)
- ✅ Le débiteur (client_id)
- ❌ Les autres (403 Forbidden)

### Qui peut créer une contestation?
- ✅ Le débiteur (client_id)
- ✅ Le créancier (creditor)
- ❌ Personne d'autre

### Qui peut résoudre une contestation?
- ✅ Le créancier UNIQUEMENT
- ❌ Le débiteur ne peut pas résoudre

## Prochaines Améliorations

- 🔔 **Notifications**: Push notification quand une dette est créée
- 📱 **SMS**: SMS notifiant l'utilisateur B
- 🔐 **Signature**: Signature numérique sur les contestations
- 📊 **Rapports**: Historique des contestations par utilisateur
- ⏰ **Auto-expiration**: Contestations non résolues après 30 jours
