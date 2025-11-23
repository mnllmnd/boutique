# 🎯 IMPLÉMENTATION : STATUT DYNAMIQUE (Solde Réel)

## 📊 LOGIQUE DE DÉTECTION

```
Solde = (Montant initial + Additions) - Paiements

✅ Solde POSITIF (≥ 0)
   → On me doit de l'argent (créance)
   → Je suis CRÉANCIER

❌ Solde NÉGATIF (< 0)
   → Je dois de l'argent (dette)
   → Je suis DÉBITEUR
```

---

## 🔄 INVERSIONS DE STATUT

### Cas 1 : Prêt initial → Devient Emprunt
```
Type initial: DEBT (Prêt)
Situation: J'ai prêté 100k mais le client m'a remboursé 120k
Solde: -20k (NÉGATIF)

Résultat:
✓ Affiche alerte: "STATUT CHANGÉ : Vous êtes maintenant DÉBITEUR"
✓ Bouton ENCAISSER → devient VERSER (couleur rouge)
✓ Libellé: "Vous avez trop encaissé ! Vous devez 20k au client"
```

### Cas 2 : Emprunt initial → Devient Prêt
```
Type initial: LOAN (Emprunt)
Situation: J'ai emprunté 50k mais j'ai remboursé 60k
Solde: +10k (POSITIF)

Résultat:
✓ Affiche alerte: "STATUT CHANGÉ : Vous êtes maintenant CRÉANCIER"
✓ Bouton REMBOURSER → devient VERSER (couleur rouge)
✓ Libellé: "Vous avez trop remboursé ! Le client vous doit 10k"
```

---

## 🎨 BOUTONS DYNAMIQUES

### **Solde POSITIF (≥ 0)**

#### PRÊT (type: 'debt', solde ≥ 0)
| Action | Bouton | Icône | Couleur |
|--------|--------|-------|---------|
| Encaisser | "ENCAISSER" | 💳 | Orange |
| Ajouter | "PRÊTER PLUS" | ⬆️ | Green |

#### EMPRUNT (type: 'loan', solde ≥ 0)
| Action | Bouton | Icône | Couleur |
|--------|--------|-------|---------|
| Rembourser | "REMBOURSER" | 💳 | Purple |
| Ajouter | "EMPRUNTER PLUS" | ⬇️ | Blue |

---

### **Solde NÉGATIF (< 0)**

#### PRÊT DEVENU EMPRUNT (type: 'debt', solde < 0)
| Action | Bouton | Icône | Couleur |
|--------|--------|-------|---------|
| Payer | "VERSER" | 📤 | Red |
| Ajouter | "EMPRUNTER PLUS" | ⬇️ | Blue |

#### EMPRUNT DEVENU PRÊT (type: 'loan', solde < 0)
| Action | Bouton | Icône | Couleur |
|--------|--------|-------|---------|
| Payer | "VERSER" | 📤 | Red |
| Ajouter | "PRÊTER PLUS" | ⬆️ | Green |

---

## 🚨 BANDEAU D'ALERTE

```
┌─────────────────────────────────────┐
│ ⚠️ STATUT CHANGÉ : Vous êtes       │
│    maintenant CRÉANCIER/DÉBITEUR    │
│                                     │
│ Vous avez trop encaissé/remboursé ! │
│ [Montant] [Au client/Vous doit]    │
└─────────────────────────────────────┘
```

**Style:**
- Fond: Rouge semi-transparent (0.12)
- Bordure: Rouge avec opacité 0.6 (2px)
- Icône: Warning Amber
- Texte: Gras, Rouge 700

---

## 📝 FORMULE DE DÉTECTION

```dart
bool _isLoan() {
  final initialType = _debt['type'] ?? 'debt';
  final remaining = _parseDouble(_debt['remaining'] ?? 0.0);
  
  if (initialType == 'debt') {
    return remaining < 0;  // Prêt → emprunt si solde < 0
  } else {
    return remaining >= 0;  // Emprunt → prêt si solde >= 0
  }
}
```

---

## 💡 ÉTAPES DE CALCUL

### HOME PAGE (Solde net)
```
totalToCollect = Somme des débits positifs
totalToRepay = Somme des débits négatifs

netBalance = totalToCollect - totalToRepay

Si netBalance > 0 → "À PERCEVOIR"
Si netBalance < 0 → "À REMBOURSER"
```

### DETAILS PAGE

```
1️⃣ Charger le solde réel
   remaining = (montant + additions) - paiements

2️⃣ Déterminer le statut dynamique
   Prêt initial + solde positif = PRÊT
   Prêt initial + solde négatif = EMPRUNT (changé!)
   Emprunt initial + solde positif = PRÊT (changé!)
   Emprunt initial + solde négatif = EMPRUNT

3️⃣ Afficher l'alerte si changement

4️⃣ Adapter les boutons
   Si solde < 0 → tous les paiements = "VERSER" (rouge)
   Si solde >= 0 → boutons normaux
```

---

## ✨ EXEMPLE COMPLET

### Scénario 1 : Sur-encaissement d'un prêt

```
Initial: PRÊT (debt) de 100k
Transaction 1: +20k addition
Transaction 2: -120k paiement

Solde = (100k + 20k) - 120k = 0k

Après:
Transaction 3: -10k paiement supplémentaire

Solde = (100k + 20k) - (120k + 10k) = -10k

INTERFACE:
[ALERTE] ⚠️ STATUT CHANGÉ : Vous êtes maintenant DÉBITEUR
         Vous avez trop encaissé ! Vous devez 10k au client

Boutons:
- VERSER (rouge) pour payer le solde négatif
- EMPRUNTER PLUS (bleu) pour ajouter un montant
```

### Scénario 2 : Sur-remboursement d'un emprunt

```
Initial: EMPRUNT (loan) de 50k
Transaction 1: -30k paiement
Transaction 2: -25k paiement supplémentaire

Solde = 50k - (30k + 25k) = -5k

INTERFACE:
[ALERTE] ⚠️ STATUT CHANGÉ : Vous êtes maintenant CRÉANCIER
         Vous avez trop remboursé ! Le client vous doit 5k

Boutons:
- VERSER (rouge) pour recevoir le remboursement du solde
- PRÊTER PLUS (vert) pour ajouter un montant
```

---

## 🎯 RÉSUMÉ

| Situation | Initial | Solde | Final | Alerte | Bouton 1 | Bouton 2 |
|-----------|---------|-------|-------|--------|----------|----------|
| Normal prêt | Debt | +100k | Prêt ✓ | ✗ | Encaisser (🟠) | Prêter plus (🟢) |
| Prêt inversé | Debt | -20k | Emprunt! | ✓ | Verser (🔴) | Emprunter plus (🔵) |
| Normal emprunt | Loan | -50k | Emprunt ✓ | ✗ | Rembourser (🟣) | Emprunter plus (🔵) |
| Emprunt inversé | Loan | +10k | Prêt! | ✓ | Verser (🔴) | Prêter plus (🟢) |

✓ = Interface s'adapte automatiquement
🔴 = "VERSER" (payer le solde inversé)
