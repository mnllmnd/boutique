# Guide Utilisateur - Séparation PRÊTS / EMPRUNTS

## 📋 Vue d'Ensemble

L'onglet "Dettes" contient désormais des **sous-onglets** qui permettent de séparer les deux types de dettes :

- **🟠 PRÊTS** : Argent que vous avez prêté à vos clients (ils vous doivent)
- **🟣 EMPRUNTS** : Argent que vous avez emprunté à vos fournisseurs ou autres (vous leur devez)

## 🎯 Comment Utiliser

### Afficher les PRÊTS
1. Ouvrez l'onglet **"DETTES"**
2. Cliquez sur le sous-onglet **"PRÊTS"** (avec l'icône 📈)
3. Vous verrez :
   - Les clients à qui vous avez prêté de l'argent
   - Le montant total à percevoir (card orange en haut)
   - Le nombre de dettes impayées

### Afficher les EMPRUNTS
1. Ouvrez l'onglet **"DETTES"**
2. Cliquez sur le sous-onglet **"EMPRUNTS"** (avec l'icône 📉)
3. Vous verrez :
   - Les fournisseurs / personnes à qui vous devez de l'argent
   - Le montant total à rembourser (card purple en haut)
   - Le nombre de remboursements en attente

## 🎨 Identification Visuelle

### Couleurs et Icônes

| Type | Couleur | Icône | Signification |
|------|---------|-------|---------------|
| PRÊTS | 🟠 Orange | 📈 | Argent à recevoir |
| EMPRUNTS | 🟣 Purple | 📉 | Argent à donner |

### Indicateurs d'État

- **Barre de soulignement** : Indique le sous-onglet actif
- **Couleur du texte** : Passe en orange/purple quand sélectionné
- **Icône** : Change aussi de couleur pour l'onglet actif

## 📊 Éléments Affichés dans Chaque Onglet

### Section PRÊTS
```
┌───────────────────────┐
│ PRÊTS (header)        │
│ 📈 1,250,000 F        │  ← Total des prêts
├───────────────────────┤
│                       │
│ Client A              │
│ Montant: 50,000 F     │
│ Impayé: 45,000 F      │
│                       │
│ Client B              │
│ Montant: 75,000 F     │
│ Impayé: 75,000 F      │
│                       │
└───────────────────────┘
```

### Section EMPRUNTS
```
┌───────────────────────┐
│ EMPRUNTS (header)     │
│ 📉 500,000 F          │  ← Total des emprunts
├───────────────────────┤
│                       │
│ Fournisseur A         │
│ Montant: 500,000 F    │
│ Dû: 500,000 F         │
│                       │
└───────────────────────┘
```

## ⚙️ Filtres Disponibles

Tous les filtres fonctionnent avec les deux sous-onglets :

### Filtre par Montant
- Ouvrez "FILTRER PAR MONTANT"
- Entrez les montants min et max
- S'applique au sous-onglet actif

### Recherche
- Tapez un nom de client ou fournisseur
- La recherche s'applique au sous-onglet sélectionné

### Tri Automatique
- Les dettes impayées s'affichent en premier
- Ensuite les dettes payées
- Les plus gros montants en haut

## 📱 Navigation

```
Onglet DETTES (principal)
│
├─ Sous-onglets:
│  ├─ PRÊTS (actif par défaut)
│  │  ├─ Filter par montant
│  │  ├─ Search
│  │  └─ Liste des clients
│  │
│  └─ EMPRUNTS
│     ├─ Filter par montant
│     ├─ Search
│     └─ Liste des fournisseurs
│
└─ Cards statistiques (toujours visibles)
   ├─ Total PRÊTS
   ├─ Total EMPRUNTS
   └─ IMPAYÉES
```

## 💡 Conseils d'Utilisation

### Pour les PRÊTS
1. Vérifiez régulièrement les clients qui vous doivent du cash
2. Utilisez le filtre "montant" pour voir les gros prêts
3. Cliquez sur chaque client pour voir l'historique détaillé

### Pour les EMPRUNTS
1. Suivez vos obligations auprès des fournisseurs
2. Organisez vos remboursements en fonction des échéances
3. Notez les clients à risque dans la section "CLIENTS À RISQUE"

## 🔄 Synchronisation

- Les données des PRÊTS et EMPRUNTS se synchronisent ensemble
- Pull-to-refresh fonctionne pour les deux sous-onglets
- Les modifications sur un prêt/emprunt s'affichent immédiatement

## ❓ FAQ

**Q: Pourquoi mes dettes n'apparaissent pas?**
A: Vérifiez que vous êtes sur le bon sous-onglet (PRÊTS ou EMPRUNTS)

**Q: Comment créer un nouveau prêt ou emprunt?**
A: Cliquez le bouton **+** au centre, puis sélectionnez le type de dette

**Q: Les cartes de statistiques changent-elles avec les sous-onglets?**
A: Les cartes PRÊTS/EMPRUNTS affichent toujours les totaux globaux. Les filtres affectent seulement la liste.

**Q: Puis-je avoir une visibilité sur les deux types en même temps?**
A: Non, vous devez basculer entre les onglets. Les statistiques des deux s'affichent en haut pour comparaison rapide.
