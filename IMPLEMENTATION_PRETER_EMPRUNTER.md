# Implémentation : Transformation PRÊTER/EMPRUNTER

## 📋 Résumé des changements

Transformation complète de l'app pour une terminologie claire et universelle : **"Qui donne / Qui reçoit l'argent"**

---

## ✅ CHANGEMENTS EFFECTUÉS

### 1️⃣ HOME PAGE - main.dart

#### Nouvelle fonction `_showAddChoice()`
- Affiche un **bottom sheet** avec deux options claires
- **PRÊTER** (flèche verte) : "Je donne l'argent au client"
- **EMPRUNTER** (flèche bleue) : "Je reçois l'argent du client"

#### FAB Button
- `onPressed: () async => await _showAddChoice();`
- Remplace l'ancien `createDebt()` direct
- Gère l'absence de clients avec dialog

#### Nouvelles fonctions
```dart
Future createDebt()   // Appelle AddDebtPage (PRÊTER)
Future createLoan()   // Appelle AddLoanPage (EMPRUNTER)
```

---

### 2️⃣ ADD DEBT PAGE - add_debt_page.dart (PRÊTER)

| Element | Avant | Après |
|---------|-------|-------|
| **Titre** | NOUVELLE DETTE | ✅ NOUVEAU PRÊT |
| **Sous-titre** | Enregistrez un nouveau montant à recouvrer | ✅ Je sors de l'argent au client |
| **Bouton** | CRÉER LA DETTE | ✅ PRÊTER |
| **Snackbar** | Dette créée | ✅ Prêt créé |
| **Type API** | - | ✅ `'type': 'debt'` |

**Logique**
- Détecte si une dette existe pour ce client
- Si oui : ajoute comme "Addition" (montant ajouté)
- Si non : crée une NOUVELLE dette avec `type: 'debt'`
- Envoie : `POST /api/debts` avec `type: 'debt'`

---

### 3️⃣ ADD LOAN PAGE - add_loan_page.dart (EMPRUNTER)

| Element | Avant | Après |
|---------|-------|-------|
| **Titre** | NOUVEL EMPRUNT | ✅ NOUVEL EMPRUNT (inchangé) |
| **Sous-titre** | Enregistrez un montant que vous devez rembourser | ✅ Je reçois de l'argent du client |
| **Bouton** | CRÉER L'EMPRUNT | ✅ EMPRUNTER |
| **Type API** | ✅ `'type': 'loan'` | (déjà présent) |

**Logique**
- Crée toujours une NOUVELLE dette avec `type: 'loan'`
- Envoie : `POST /api/debts/loans` avec `type: 'loan'`

---

### 4️⃣ DEBT DETAILS PAGE - debt_details_page.dart

#### Nouvelles helper functions
```dart
bool _isLoan()  // Retourne true si type == 'loan'
String _getAddButtonLabel()  // "Prêter plus" ou "Emprunter plus"
String _getPaymentButtonLabel()  // "Encaisser" ou "Rembourser"
```

#### AppBar Actions - Boutons dynamiques
| Cas | Bouton "Ajouter" | Bouton "Paiement" |
|-----|------------------|-------------------|
| **PRÊT** (type: 'debt') | 🟢 "Prêter plus" | "Encaisser" |
| **EMPRUNT** (type: 'loan') | 🔵 "Emprunter plus" | "Rembourser" |

---

## 🎯 TERMINOLOGIE UNIVERSELLE

### Type 'debt' = JE PRÊTE (Créancier)
- ✅ Je **sors** de l'argent
- ✅ Je dois **encaisser** (recevoir le paiement)
- ✅ Je peux **prêter plus** (ajouter montant)

### Type 'loan' = J'EMPRUNTE (Débiteur)
- ✅ Je **reçois** de l'argent
- ✅ Je dois **rembourser** (payer)
- ✅ Je peux **emprunter plus** (ajouter à ma dette)

---

## 📊 FLUX UTILISATEUR

```
HOME PAGE (+) Button
    ↓
Bottom Sheet CHOICE
    ├─ PRÊTER (vert) ─→ AddDebtPage
    │   └─ Créer/Ajouter à une dette
    │   └─ POST /api/debts {type: 'debt'}
    │
    └─ EMPRUNTER (bleu) ─→ AddLoanPage
        └─ Créer nouvel emprunt
        └─ POST /api/debts/loans {type: 'loan'}

DEBT DETAILS PAGE
    ├─ Bouton "Prêter plus" / "Rembourser" (dynamique)
    └─ Bouton "Encaisser" / "Rembourser" (dynamique)
```

---

## 🔄 API INTÉGRATION

### Backend doit supporter
```json
POST /api/debts
{
  "client_id": 123,
  "amount": 50000,
  "type": "debt",  // ✅ NOUVEAU CHAMP
  "due_date": "2024-12-31",
  "notes": "..."
}
```

```json
POST /api/debts/loans
{
  "client_id": 456,
  "amount": 30000,
  "type": "loan",  // ✅ NOUVEAU CHAMP
  "due_date": "2025-01-15",
  "notes": "..."
}
```

---

## ✨ AMÉLIORATIONS UX

✅ **Interface claire** : Les couleurs et libellés indiquent clairement le flux d'argent
✅ **Choix explicite** : L'utilisateur sait immédiatement s'il prête ou emprunte
✅ **Terminologie cohérente** : Même concept, même mot partout
✅ **Boutons contextuels** : Actions adaptées au type de transaction
✅ **Snackbars informatifs** : "Prêt créé" vs "Emprunt ajouté"

---

## 📝 NOTES IMPORTANTES

1. **Logique calculs inchangée** : Le backend gère les deux types de la même manière
2. **API extensible** : Le champ `type` permet de futurs filtres/rapports
3. **Rétrocompatibilité** : Les dettes existantes sans `type` sont traitées par défaut
4. **Flux d'addition** : 
   - PRÊT : Ajoute à la dette existante si elle existe
   - EMPRUNT : Crée toujours une nouvelle (pas d'addition)

---

## 🧪 À TESTER

- [x] Bottom sheet affiche correctement les deux options
- [x] PRÊTER crée une dette avec type: 'debt'
- [x] EMPRUNTER crée un emprunt avec type: 'loan'
- [x] Les boutons sont dynamiques dans debt_details_page
- [x] Les snackbars sont corrects
- [ ] Les paiements/remboursements fonctionnent correctement
- [ ] Les rapports/stats peuvent filtrer par type

---

## 📂 FICHIERS MODIFIÉS

1. ✅ `mobile/lib/main.dart` - FAB et bottom sheet
2. ✅ `mobile/lib/add_debt_page.dart` - Textes PRÊTER
3. ✅ `mobile/lib/add_loan_page.dart` - Textes EMPRUNTER  
4. ✅ `mobile/lib/debt_details_page.dart` - Labels dynamiques

---

**Status:** ✅ IMPLÉMENTATION COMPLÈTE

Prêt pour test et déploiement.
