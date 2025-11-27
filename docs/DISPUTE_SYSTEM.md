# 🚀 Système Innovant de Contestation de Dettes

## Vue d'ensemble

Ce système permet à un utilisateur B de **contester une dette créée par l'utilisateur A** sans avoir besoin de la confirmer d'abord. C'est une approche moderne et pragmatique qui reconnaît que certains utilisateurs ne vont pas confirmer une dette car ils ne l'assument pas.

## Fonctionnalités

### 1. **Création de Contestation**
- L'utilisateur B (débiteur/emprunteur) peut contester une dette, addition, paiement ou remboursement
- Il doit spécifier une **raison** (obligatoire) et un **message détaillé** (optionnel)
- Exemples de raisons:
  - "Montant incorrect"
  - "Doublon"
  - "Erreur de date"
  - "Personne erronée"
  - "Pas d'accord avec les conditions"

### 2. **Statut de la Dette**
Les dettes peuvent avoir les statuts suivants:
- `none` - Aucune contestation
- `disputed` - Une ou plusieurs contestations actives
- `resolved` - Toutes les contestations ont été résolues

### 3. **Historique des Contestations**
- Chaque contestation est enregistrée avec:
  - L'identité du contestataire
  - La date et heure de création
  - La raison et le message
  - Le statut (résolue ou en attente)
  - La note de résolution (si applicable)

### 4. **Résolution**
- L'utilisateur A (créancier) voit les contestations et peut les résoudre
- Il doit fournir une note de résolution expliquant sa décision
- Une fois résolue, la contestation reste visible dans l'historique

## Architecture Backend

### Nouvelle Migration (014_add_dispute_system.sql)
```sql
-- Table pour tracker les contestations
CREATE TABLE debt_disputes (
  id SERIAL PRIMARY KEY,
  debt_id INTEGER NOT NULL,
  disputed_by TEXT NOT NULL,
  reason TEXT NOT NULL,
  message TEXT,
  created_at TIMESTAMP DEFAULT NOW(),
  resolved_at TIMESTAMP,
  resolution_note TEXT
);

-- Colonnes ajoutées à la table debts
ALTER TABLE debts ADD COLUMN created_by TEXT;
ALTER TABLE debts ADD COLUMN dispute_status TEXT DEFAULT 'none';
```

### Nouvelles Routes API

#### POST /debts/:id/disputes
Créer une contestation
```json
{
  "reason": "Montant incorrect",
  "message": "Je n'ai jamais emprunté 5000 F, c'était 3000 F"
}
```

#### GET /debts/:id/disputes
Récupérer les contestations d'une dette

#### PATCH /debts/:id/disputes/:disputeId/resolve
Résoudre une contestation
```json
{
  "resolution_note": "Après vérification, le montant était correct. Débats réglés."
}
```

## Flux d'Utilisation

### Scénario 1: Utilisateur B conteste une dette
1. Utilisateur A crée une dette pour Utilisateur B
2. Utilisateur B reçoit un badge/notification
3. Utilisateur B ouvre la page de détails et voit le bouton "CONTESTER CETTE DETTE"
4. Utilisateur B remplit le formulaire avec raison et message
5. La contestation est créée et stockée dans l'historique
6. Utilisateur A voit la contestation dans l'onglet Détails
7. Utilisateur A peut résoudre la contestation avec une note explicative

### Scénario 2: Utilisateur B conteste une addition
Même flux, mais appliqué à une addition ou un paiement

## Interface Utilisateur

### Page de Détails de la Dette
```
┌─────────────────────────────────┐
│   MONTANT: 1500 F               │
│   AZIZ vous doit ───────────────│
└─────────────────────────────────┘

CONTESTATIONS
⚠️ 1 contestation en attente

┌─────────────────────────────────┐
│ Contestation de AZIZ            │
│ Date: 26/11/2025 14:30          │ [En attente]
├─────────────────────────────────┤
│ Raison: Montant incorrect       │
│                                 │
│ > Je n'ai jamais emprunté      │
│   5000 F, c'était 3000 F        │
└─────────────────────────────────┘

[⚠️ CONTESTER CETTE DETTE]
```

## Avantages

✅ **Traçabilité complète** - Chaque contestation est enregistrée
✅ **Résolution de conflits** - Permet une discussion structurée
✅ **Pas de blocage** - La dette reste valide jusqu'à résolution
✅ **Transparence** - Historique visible pour les deux parties
✅ **Preuves** - Messages détaillés qui servent de preuves
✅ **Scalabilité** - Système qui grandit avec les besoins

## Cas d'Usage

- **Disputes de montants** - "J'ai donné 2000 F pas 3000 F"
- **Erreurs de dates** - "Ça s'est passé le 20 mai pas le 15"
- **Doublons** - "Vous l'avez déjà enregistré hier"
- **Personne erronée** - "C'est avec Ahmed pas avec Aziz"
- **Conditions disconses** - "On avait dit 10% d'intérêt pas 15%"

## Exemple Complet

```
Utilisateur A (Créancier): Ahmed
Utilisateur B (Débiteur): Aziz

1. Ahmed crée une dette: Aziz doit 5000 F
   Status: none

2. Aziz conteste:
   Raison: "Montant incorrect"
   Message: "Ahmed m'a dit 3000 F en tête-à-tête"
   Status: disputed

3. Ahmed voit la contestation et répond:
   Resolution note: "Aziz a raison, c'était 3000 F. Je corrige l'entrée."
   Status: resolved

4. Les deux voient l'historique complet de la contestation
```

## Prochaines Améliorations

- 🔔 Notifications en temps réel des contestations
- 📱 Push notifications
- 🎯 Assignation à un modérateur
- 📊 Statistiques des contestations par utilisateur
- 🔐 Signatures numériques pour les résolutions
