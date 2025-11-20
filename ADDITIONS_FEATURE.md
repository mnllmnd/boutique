# Fonctionnalité d'Additions de Montants aux Dettes

## Vue d'ensemble

La nouvelle fonctionnalité permet de **modifier le montant d'une dette existante en ajoutant progressivement des montants supplémentaires** au lieu de créer une nouvelle dette chaque fois qu'une personne revient avec une nouvelle dépense. Chaque addition est enregistrée avec un historique complet pour faciliter le suivi.

## Architecture

### 1. Base de Données

**Table `debt_additions`**
```sql
CREATE TABLE debt_additions (
  id SERIAL PRIMARY KEY,
  debt_id INTEGER NOT NULL REFERENCES debts(id) ON DELETE CASCADE,
  amount NUMERIC(12,2) NOT NULL,
  notes TEXT,
  added_at TIMESTAMP NOT NULL DEFAULT NOW(),
  created_at TIMESTAMP DEFAULT NOW()
);
```

**Indices pour performance :**
- `idx_debt_additions_debt_id` : Recherche rapide des additions par dette
- `idx_debt_additions_added_at` : Tri chronologique efficace

### 2. API Backend (Express.js)

#### Endpoints créés

**POST `/api/debts/:id/add`** - Ajouter un montant à une dette existante
- **Body:**
  ```json
  {
    "amount": 50000,
    "added_at": "2024-11-20T10:30:00.000Z",
    "notes": "Client revient avec une nouvelle dépense"
  }
  ```
- **Réponse (201 Created):**
  ```json
  {
    "addition": {
      "id": 1,
      "debt_id": 42,
      "amount": 50000,
      "notes": "...",
      "added_at": "2024-11-20T10:30:00.000Z"
    },
    "new_debt_amount": 150000
  }
  ```
- **Comportement:**
  - Enregistre l'addition dans la table `debt_additions`
  - **Met à jour automatiquement** le montant total de la dette
  - Enregistre l'action dans le journal d'activité

**GET `/api/debts/:id/additions`** - Récupérer l'historique des additions
- **Réponse (200 OK):**
  ```json
  [
    {
      "id": 1,
      "debt_id": 42,
      "amount": 50000,
      "notes": "Achat de riz",
      "added_at": "2024-11-20T10:30:00.000Z"
    },
    {
      "id": 2,
      "debt_id": 42,
      "amount": 30000,
      "notes": "Achat de sucre",
      "added_at": "2024-11-21T14:15:00.000Z"
    }
  ]
  ```

**DELETE `/api/debts/:id/additions/:additionId`** - Supprimer une addition
- **Réponse (200 OK):**
  ```json
  {
    "success": true,
    "new_debt_amount": 50000
  }
  ```
- **Comportement:**
  - Supprime l'addition
  - **Réduit automatiquement** le montant total de la dette
  - Enregistre la suppression dans le journal d'activité

### 3. Interface Mobile (Flutter)

#### Nouveaux fichiers

**`add_addition_page.dart`** - Page pour ajouter une addition
- Champ de saisie du montant
- Sélecteur de date (par défaut = aujourd'hui)
- Champ de notes optionnel
- Affichage du montant actuel de la dette
- Validation des montants positifs
- Gestion des erreurs réseau

**Modifications à `debt_action_sheet.dart`**
- Importation du fichier `add_addition_page.dart`
- Variable d'état `List additions`
- Méthode `_loadAdditions()` pour charger l'historique
- Méthode `_addAddition()` pour naviguer vers la page d'ajout
- **Nouvelle section "HISTORIQUE DES ADDITIONS"** affichant :
  - Nombre total d'additions
  - Liste des additions avec :
    - Montant (couleur orange)
    - Date et heure
    - Notes explicatives
    - Icône visuelle (add_circle)
  - Message vide si aucune addition
- **Nouveau bouton "AJOUTER UN MONTANT"** (couleur orange)
- Réorganisation des boutons d'action (addition avant paiement)

## Flux de utilisation

### 1. Ajouter un montant à une dette existante

```
1. Utilisateur affiche les détails d'une dette (DebtActionSheet)
2. Clique sur le bouton "AJOUTER UN MONTANT" (orange)
3. Page AddAdditionPage s'ouvre
4. Remplit:
   - Montant à ajouter (obligatoire)
   - Date (par défaut = aujourd'hui)
   - Note explicative (optionnel)
5. Clique sur "AJOUTER LE MONTANT"
6. API crée l'enregistrement et met à jour la dette
7. Historique se rafraîchit automatiquement
8. Le bouton callback notify() permet à l'écran principal de se rafraîchir
```

### 2. Consulter l'historique

```
1. Ouvrir DebtActionSheet pour une dette
2. Voir la section "HISTORIQUE DES ADDITIONS"
3. Additions listées en ordre chronologique décroissant
4. Chaque addition montre: montant, date, notes optionnelles
```

### 3. Supprimer une addition

```
1. Admin peut appeler DELETE /api/debts/:id/additions/:additionId
2. Le montant de la dette est automatiquement réduit
3. (Note: UI de suppression pas encore implémentée - peut être ajoutée)
```

## Points clés techniques

### Calcul du montant total

Le montant actuel de la dette dans la colonne `amount` de la table `debts` est **toujours à jour** :
- Montant initial + Somme de toutes les additions - (pas d'effet des paiements sur le montant)

### Sécurité

- Vérification du header `x-owner` pour authentifier l'utilisateur
- Les utilisateurs ne peuvent voir/modifier que leurs propres dettes
- Utilisation de requêtes paramétrées pour prévenir les injections SQL

### Performance

- Index sur `debt_id` pour recherches rapides
- Index sur `added_at` pour tri chronologique optimisé
- Requête `SELECT` avec `ORDER BY added_at DESC` pour l'ordre décroissant

### Suivi d'activité

Chaque action d'addition est enregistrée dans `activity_log` :
```json
{
  "action": "debt_addition",
  "details": {
    "addition_id": 1,
    "debt_id": 42,
    "amount": 50000
  }
}
```

## Intégration avec les paiements

Les paiements et additions sont **indépendants** :
- **Additions** : modifient le montant INITIAL de la dette
- **Paiements** : réduisent le montant PAYÉ (colonne `payments`)
- Le "Reste à payer" = Montant total - Total payé

## Avantages de cette approche

1. **Suivi historique complet** : Chaque addition est enregistrée avec date et notes
2. **Pas de duplication** : Une seule dette par client avec additions progressives
3. **Flexibilité** : Permet d'annuler une addition si erreur (DELETE)
4. **Clarté UI** : Section "Historique des additions" clairement séparée des paiements
5. **Auditabilité** : Journal d'activité complète pour chaque action

## Cas d'usage

**Avant cette fonctionnalité :**
```
Client A doit 100,000 FCFA
→ Client A revient, nouvel achat 50,000 FCFA
→ Créer une NOUVELLE dette de 50,000 (problématique!)
→ Maintenant 2 dettes pour le même client à gérer
```

**Avec cette fonctionnalité :**
```
Client A doit 100,000 FCFA (DETTE #42)
→ Client A revient, nouvel achat 50,000 FCFA
→ AJOUTER 50,000 à la DETTE #42 (via AddAdditionPage)
→ Montant total: 150,000 FCFA avec historique complet
→ Encore UNE SEULE dette à gérer
```

## Fichiers modifiés/créés

| Fichier | Type | Description |
|---------|------|-------------|
| `backend/migrations/006_add_debt_additions.sql` | Créé | Schéma de la table |
| `backend/routes/debts.js` | Modifié | 3 nouveaux endpoints |
| `mobile/lib/add_addition_page.dart` | Créé | Page Flutter d'ajout |
| `mobile/lib/debt_action_sheet.dart` | Modifié | Intégration des additions |

## Étapes de déploiement

1. **Exécuter la migration SQL :**
   ```bash
   # La migration est automatiquement appliquée au démarrage du backend
   # grâce au système de migration existant (migrate.sql)
   ```

2. **Redémarrer le backend :**
   ```bash
   npm start  # ou votre commande habituelle
   ```

3. **Recompiler l'app Flutter :**
   ```bash
   flutter clean
   flutter pub get
   flutter run
   ```

## Tests recommandés

### Backend

```bash
# Tester l'ajout d'une addition
curl -X POST http://localhost:3000/api/debts/42/add \
  -H "Content-Type: application/json" \
  -H "x-owner: test_owner" \
  -d '{"amount": 50000, "notes": "Test addition"}'

# Tester la récupération des additions
curl http://localhost:3000/api/debts/42/additions \
  -H "x-owner: test_owner"

# Tester la suppression
curl -X DELETE http://localhost:3000/api/debts/42/additions/1 \
  -H "x-owner: test_owner"
```

### Mobile

1. Ouvrir une dette existante
2. Cliquer sur "AJOUTER UN MONTANT"
3. Entrer un montant et une note
4. Vérifier l'ajout dans l'historique
5. Vérifier le montant total mis à jour dans l'écran principal

---

**Version:** 1.0
**Date:** 20 novembre 2024
**Statut:** Implémentation complète
