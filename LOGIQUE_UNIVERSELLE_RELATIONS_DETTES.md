# ✨ LOGIQUE UNIVERSELLE : RELATIONS DE DETTES

## 🎯 CONCEPT FONDAMENTAL

**Oubliez les rôles "boutiquiers" vs "clients"**

Pensez simplement : **X doit payer Y une certaine somme**

Peu importe qui est qui, l'interface fait toujours la même chose :
- **"PAYER"** → réduit le montant
- **"AJOUTER MONTANT"** → augmente le montant

---

## 📊 COLONNES BASE DE DONNÉES

```sql
from_user   → Celui qui doit payer
to_user     → Celui qui doit recevoir
balance     → Montant que from_user doit à to_user
```

### Exemples :

**Cas 1 : Je prête 100k à Ali**
```
from_user = 'Ali'
to_user = 'Moi'
balance = +100k  (Ali me doit 100k)

Type initial = 'debt' (prêt)
```

**Cas 2 : J'emprunte 50k à Ahmed**
```
from_user = 'Moi'
to_user = 'Ahmed'
balance = +50k  (Je dois 50k à Ahmed)

Type initial = 'loan' (emprunt)
```

---

## 🔄 COMPORTEMENT UNIVERSEL

### Quand `balance > 0`
```
from_user DOIT PAYER à to_user

Bouton "PAYER" :
  → Réduit balance (from_user paie une partie)
  → Si balance devient 0, dette liquidée
  → Si balance devient négatif, RELATION S'INVERSE

Bouton "AJOUTER MONTANT" :
  → Augmente balance (from_user emprunte plus)
```

### Quand `balance < 0`
```
to_user DOIT PAYER à from_user (relation inversée)

Exemple : from_user = 'Ali', to_user = 'Moi', balance = -50k
→ Moi doit payer 50k à Ali

Bouton "PAYER" :
  → Réduit le montant négatif (Moi je paie à Ali)
  → Si balance devient 0, dette liquidée
  → Si balance devient positif, RELATION S'INVERSE

Bouton "AJOUTER MONTANT" :
  → Augmente le montant (Moi j'ajoute une nouvelle dette)
```

---

## 🚨 ALERTE DE RELATION INVERSÉE

### Condition
```
Si la relation s'est inversée (balance a changé de signe)
   → Afficher alerte : "⚠️ RELATION INVERSÉE"
```

### Exemple 1 : Prêt devenu emprunt
```
Initial type = 'debt'
Montant prêté = 100k
Montant reçu = 150k
Balance = -50k

Alerte:
"⚠️ RELATION INVERSÉE
 Vous devez maintenant 50k à Ali"
```

### Exemple 2 : Emprunt remboursé en excès
```
Initial type = 'loan'
Montant emprunté = 50k
Montant remboursé = 80k
Balance = -30k (négatif = relation inversée)

Alerte:
"⚠️ RELATION INVERSÉE
 Ahmed vous doit maintenant 30k"
```

---

## 💡 INTERFACE COHÉRENTE

| Situation | Balance | from_user | to_user | Bouton PAYER | Bouton AJOUTER | Notes |
|-----------|---------|-----------|---------|--------------|----------------|-------|
| Prêt normal | +100k | Ali | Moi | Réduit 100k | Ajoute prêt | Ali me paye |
| Prêt inversé | -50k | Ali | Moi | Réduit -50k | Ajoute prêt | Moi paye Ali |
| Emprunt normal | +50k | Moi | Ahmed | Réduit 50k | Ajoute emprunt | Je paie Ahmed |
| Emprunt inversé | -30k | Moi | Ahmed | Réduit -30k | Ajoute emprunt | Ahmed me paie |

**Tous les cas utilisent les mêmes boutons avec le même comportement !** ✓

---

## 🧮 LOGIQUE DE PAIEMENT

```dart
// Quand on clique "PAYER"
if (montantPaiement > 0) {
    balance -= montantPaiement;  // Réduit toujours la dette
}

// Si balance s'inverse :
if (balance < 0) {
    // Afficher alerte : relation a basculé
    // from_user et to_user ont maintenant des rôles inversés
}
```

---

## 🏠 HOME PAGE : SOLDE NET UNIVERSEL

```
Pour chaque dette :
  if (balance > 0)  → from_user doit à to_user
  if (balance < 0)  → to_user doit à from_user

totalPositif = somme de tous les balance > 0
totalNégatif = somme de tous les |balance| < 0

netBalance = totalPositif - totalNégatif

if (netBalance > 0) → "À RECEVOIR"
if (netBalance < 0) → "À PAYER"
if (netBalance = 0) → "ÉQUILIBRÉ"
```

---

## ✨ AVANTAGES

✅ **Universel** : Pas besoin de logique différente pour prêts/emprunts  
✅ **Cohérent** : Les mêmes boutons font toujours la même chose  
✅ **Flexible** : Gère les inversions de relation naturellement  
✅ **Clair** : Interface comprend automatiquement qui doit quoi  
✅ **Maintenable** : Une seule page, une seule logique  

---

## 📝 CODE KEY FUNCTIONS

```dart
// ✅ Définir qui doit payer à qui
String _getPaymentButtonLabel() {
  return 'PAYER';  // Toujours pareil !
}

String _getAddButtonLabel() {
  return 'AJOUTER MONTANT';  // Toujours pareil !
}

// ✅ Détecter une inversion
String? _getStatusChangeMessage() {
  final balance = _parseDouble(_debt['balance'] ?? 0.0);
  final initialType = _getInitialType();
  
  // Si prêt initial mais balance < 0
  if (initialType == 'debt' && balance < 0) {
    return '⚠️ RELATION INVERSÉE';
  }
  // Si emprunt initial mais balance > 0
  if (initialType == 'loan' && balance > 0) {
    return '⚠️ RELATION INVERSÉE';
  }
  return null;
}
```

---

## 🎉 CONCLUSION

Avec cette logique, l'application devient **vraiment universelle et intelligente**.

Elle n'a plus besoin de savoir si c'est un "prêt" ou un "emprunt" - elle regarde juste la valeur actuelle et adapte l'interface en conséquence !
