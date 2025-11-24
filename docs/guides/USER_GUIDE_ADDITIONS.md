# Guide d'utilisation - Ajouter un montant à une dette existante

## 🎯 Objectif

Au lieu de créer une **nouvelle dette** chaque fois qu'un client revient, vous pouvez maintenant **ajouter un montant** à une dette existante. Cela permet un suivi clair et une meilleure organisation.

## 📋 Situation typique

**Scénario:**
- Lundi: Client A achète pour 100,000 FCFA → Vous créez une DETTE
- Mercredi: Client A revient, achète pour 50,000 FCFA supplémentaires

**Avant cette fonction:** Vous deviez créer une 2ème dette → Confusion, 2 dettes à gérer
**Maintenant:** Vous pouvez ajouter 50,000 FCFA à la 1ère dette → 1 seule dette avec historique!

---

## 🔧 Comment faire?

### Étape 1️⃣ : Ouvrir la dette existante

1. Allez dans **CLIENTS**
2. Cliquez sur le client concerné
3. Sélectionnez la **DETTE** à laquelle ajouter un montant
4. La page **DÉTAILS DE LA DETTE** s'ouvre

### Étape 2️⃣ : Ajouter un montant

1. Vous verrez deux sections :
   - **HISTORIQUE DES PAIEMENTS** (en bas, pour enregistrer les paiements)
   - **HISTORIQUE DES ADDITIONS** (liste des montants ajoutés)

2. Cliquez sur le bouton **AJOUTER UN MONTANT** (bouton orange)

### Étape 3️⃣ : Remplir le formulaire

La page d'ajout affiche:

```
📌 CLIENT: Nom du client
💰 MONTANT ACTUEL DE LA DETTE: XXX FCFA

Champs à remplir:
┌──────────────────────────────────────────┐
│ MONTANT À AJOUTER                        │
│ [_________ FCFA ________]  ← obligatoire │
├──────────────────────────────────────────┤
│ DATE                                     │
│ [20/11/2024] ← cliquable, par défaut=auj│
├──────────────────────────────────────────┤
│ NOTE (OPTIONNEL)                         │
│ [Achat de riz du client...]    ← optionnel
│                                          │
└──────────────────────────────────────────┘

Bouton: [AJOUTER LE MONTANT]
```

**Remplissage :**

| Champ | Description | Obligatoire |
|-------|-------------|:-----------:|
| **Montant à ajouter** | Le montant supplémentaire | ✅ Oui |
| **Date** | Quand a eu lieu l'achat? Clique pour changer | ❌ Non (défaut = aujourd'hui) |
| **Note** | Pourquoi ce montant? (ex: "Achat de riz") | ❌ Non |

### Étape 4️⃣ : Valider

Cliquez sur **AJOUTER LE MONTANT**

**Résultat :**
- ✅ Le montant est ajouté
- ✅ Vous revenez aux détails de la dette
- ✅ La section "HISTORIQUE DES ADDITIONS" se met à jour automatiquement
- ✅ Le montant total de la dette augmente

---

## 📊 Exemple pratique

### Situation initiale
```
DÉTAILS DE LA DETTE
════════════════════
CLIENT: Aminata Diallo
MONTANT: 100,000 FCFA
PAYÉ: 0 FCFA
RESTE: 100,000 FCFA

HISTORIQUE DES ADDITIONS: 0
└─ Aucune addition

HISTORIQUE DES PAIEMENTS: 0
└─ Aucun paiement
```

### Vous cliquez "AJOUTER UN MONTANT"
```
Remplissez:
- Montant: 50,000
- Date: 20/11/2024
- Note: "Client revient, achat de sucre"

Cliquez AJOUTER LE MONTANT
```

### Après ajout
```
DÉTAILS DE LA DETTE
════════════════════
CLIENT: Aminata Diallo
MONTANT: 150,000 FCFA ← AUGMENTÉ!
PAYÉ: 0 FCFA
RESTE: 150,000 FCFA ← RECALCULÉ!

HISTORIQUE DES ADDITIONS: 1 ✨ NOUVEAU!
├─ 50,000 FCFA | 20/11/2024 10:30
│  "Client revient, achat de sucre"

HISTORIQUE DES PAIEMENTS: 0
└─ Aucun paiement
```

### Client paie 100,000 FCFA
```
Cliquez sur "AJOUTER UN PAIEMENT"
Montant: 100,000
```

### Résultat final
```
DÉTAILS DE LA DETTE
════════════════════
CLIENT: Aminata Diallo
MONTANT: 150,000 FCFA
PAYÉ: 100,000 FCFA
RESTE: 50,000 FCFA

HISTORIQUE DES ADDITIONS: 1
├─ 50,000 FCFA | 20/11/2024 10:30 🟠
│  "Client revient, achat de sucre"

HISTORIQUE DES PAIEMENTS: 1
├─ 100,000 FCFA | 20/11/2024 15:45 🟢
   PAIEMENT (aucune note)
```

---

## ❓ Questions fréquentes

**Q: Puis-je ajouter plusieurs montants à la même dette?**
A: ✅ Oui! Autant de fois que vous le souhaitez. L'historique les affiche tous en ordre chronologique.

**Q: Quel est la différence entre "Ajouter un montant" et "Ajouter un paiement"?**
A: 
- **Ajouter un montant** = Le client doit PLUS d'argent (augmente la dette)
- **Ajouter un paiement** = Le client paie une partie (réduit ce qu'il reste à payer)

**Q: Les notes sont-elles vraiment optionnelles?**
A: ✅ Oui, mais fortement recommandées pour suivre pourquoi le montant a augmenté (ex: "achat de riz", "crédit supplémentaire", etc.)

**Q: Que se passe-t-il si je me trompe de montant?**
A: Pour le moment, il n'y a pas de bouton "Supprimer une addition" dans l'interface, mais cela peut être ajouté. Vous pouvez contacter l'admin.

**Q: Le montant total change immédiatement?**
A: ✅ Oui! Dès que vous cliquez "AJOUTER LE MONTANT", le montant total est recalculé et vous revenez à la vue détails.

**Q: Puis-je ajouter un montant rétroactif (date passée)?**
A: ✅ Oui! Vous pouvez cliquer sur le champ DATE et sélectionner une date antérieure. C'est utile pour les ajouts oubliés.

**Q: Le système garde-t-il un historique?**
A: ✅ Oui! Chaque addition est enregistrée avec:
- La date exacte
- L'heure précise  
- La note explicative
- Et est visible dans "HISTORIQUE DES ADDITIONS"

---

## 🎨 Visuels dans l'app

### Boutons identifiables

```
AJOUTER UN MONTANT     ← Bouton ORANGE
[________________]        Ajoute une dette

AJOUTER UN PAIEMENT    ← Bouton NOIR/BLANC
[________________]        Enregistre un paiement

SUPPRIMER LA DETTE     ← Bouton ROUGE
[________________]        Supprime complètement
```

### Icônes dans l'historique

```
HISTORIQUE DES ADDITIONS (2)
├─ 🟠 ORANGE = Une addition (montant ajouté)
│  50,000 FCFA | 20/11/2024 | "Note explicative"

HISTORIQUE DES PAIEMENTS (1)
├─ 🟢 VERT = Un paiement (montant payé)
   100,000 FCFA | 20/11/2024 15:45
```

---

## 💡 Conseils

✅ **À FAIRE:**
- Notez le motif de chaque addition ("achat de riz", "crédit supplémentaire", etc.)
- Utilisez les additions pour les achats progressifs du MÊME client
- Vérifiez le montant total avant de valider

❌ **À ÉVITER:**
- Ne créez pas 2 dettes pour le même client → Utilisez plutôt "Ajouter un montant"
- Ne mélangez pas addition et paiement (ce sont deux actions différentes!)
- Ne modifiez pas manuellement les chiffres (laissez le système calculer)

---

## 📞 Aide & Support

Si vous avez un problème:
1. Vérifiez que le montant est positif (>0)
2. Vérifiez votre connexion réseau
3. Contactez votre administrateur

---

**Version:** 1.0 | **Dernière mise à jour:** 20 novembre 2024
