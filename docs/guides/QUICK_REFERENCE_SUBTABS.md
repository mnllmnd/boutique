# QUICK REFERENCE - Sous-Onglets PRÊTS/EMPRUNTS

## ✅ Ce Qui a Été Fait

Ajout d'un système de **sous-onglets** dans l'onglet \"DETTES\" pour séparer visuellement :
- **PRÊTS** 🟠 (debt_type == 'debt') 
- **EMPRUNTS** 🟣 (debt_type == 'loan')

## 🎯 Résultat Final

### Interface Utilisateur
```
┌──────────────────────────────────────────────┐
│ DETTES                                       │
├──────────────────────────────────────────────┤
│                                              │
│ PRÊTS: 1,250,000 F  │  EMPRUNTS: 500,000 F │
│ IMPAYÉES: 5                                  │
│                                              │
│ [FILTRER PAR MONTANT]                        │
│ Min: ___    Max: ___                         │
│                                              │
│ ┌─ PRÊTS 📈 ─┬─ EMPRUNTS 📉 ─┐  ← NOUVEAU │
│ │ ════════   │                 │              │
│ │            │                 │              │
│ │ RÉCENT     │                 │              │
│ │            │                 │              │
│ │ ├─ Client A                  │              │
│ │ │  50,000 F (Prêt)          │              │
│ │ │                            │              │
│ │ ├─ Client B                  │              │
│ │ │  75,000 F (Prêt)          │              │
│ │ │                            │              │
│ └─────────────────────────────┘              │
│                                              │
│ CLIENTS À RISQUE                            │
│ ├─ Client A: 75,000 F                       │
│                                              │
└──────────────────────────────────────────────┘
```

## 📝 Changements de Code

### Ajouté 1 ligne dans _HomePageState
```dart
String _debtSubTab = 'prets';  // ← Variable d'état
```

### Modifié _buildDebtsTab() - 3 Sections

**Section 1: Filtrer par type (après filtre montant)**
```dart
// Filtrer par sous-onglet actif
if (_debtSubTab == 'prets') {
  filteredDebts = filteredDebts.where((d) => (d['type'] ?? 'debt') == 'debt').toList();
} else if (_debtSubTab == 'emprunts') {
  filteredDebts = filteredDebts.where((d) => (d['type'] ?? 'debt') == 'loan').toList();
}
```

**Section 2: Adapter recentItems (selon sous-onglet)**
```dart
final List<dynamic> recentItems = [];
if (_debtSubTab == 'prets') {
  recentItems.addAll(prets);
  // ...
} else if (_debtSubTab == 'emprunts') {
  recentItems.addAll(emprunts);
  // ...
} else {
  // ... code par défaut
}
```

**Section 3: UI Sous-onglets (NOUVEAU widget)**
```dart
Row(
  children: [
    // Onglet PRÊTS
    Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _debtSubTab = 'prets'),
        child: Container(
          // ... styling with bottom border
          child: Column(
            children: [
              Icon(Icons.trending_up),
              Text('PRÊTS'),
            ],
          ),
        ),
      ),
    ),
    // Onglet EMPRUNTS (similaire avec purple)
  ],
)
```

## 🔌 Intégration avec Code Existant

| Élément | Avant | Après |
|---------|-------|-------|
| **Cards PRÊTS/EMPRUNTS** | Affichent totaux globaux | Inchangé ✓ |
| **Filtre montant** | S'applique à tout | S'applique au sous-onglet ✓ |
| **Recherche** | Cherche tout | Cherche dans le sous-onglet ✓ |
| **Tri** | Global | Par sous-onglet ✓ |
| **Clients à risque** | De tous les types | Du type actif ✓ |

## 🎨 Couleurs et Icônes

| Élément | Active | Inactive |
|---------|--------|----------|
| **PRÊTS** | 🟠 Orange + Underline | 🔘 Gris |
| **EMPRUNTS** | 🟣 Purple + Underline | 🔘 Gris |

## 📊 Logique de Filtrage

```
Étape 1: Charger toutes les dettes
         ↓
Étape 2: Filtrer par montant (min/max)
         ↓
Étape 3: Filtrer par type (_debtSubTab) ← NOUVEAU
         ├─ 'prets' → type == 'debt'
         └─ 'emprunts' → type == 'loan'
         ↓
Étape 4: Grouper par client|type
         ↓
Étape 5: Trier (impayé en premier, puis montant)
         ↓
Étape 6: Afficher recentItems filtrés
```

## 🚀 Comment Tester

1. **Compilation**
   ```bash
   cd mobile/
   flutter pub get
   flutter analyze
   ```

2. **Test Manuel**
   - Ouvrir l'app
   - Aller à l'onglet DETTES
   - Voir PRÊTS par défaut (orange actif)
   - Cliquer EMPRUNTS → voir changement immédiat
   - Appliquer filtres → vérifier fonctionnement

3. **Cas de Test**
   - [ ] Basculer PRÊTS ↔ EMPRUNTS = ok
   - [ ] Liste change correctement = ok
   - [ ] Filtres montant fonctionnent = ok
   - [ ] Recherche filtre bien = ok
   - [ ] Cards stats affichent bon montant = ok
   - [ ] Clients à risque changent = ok

## 📌 Points Importants

✅ **Compatibilité**: Tous les filtres existants fonctionnent  
✅ **Performant**: Même complexité O(n log n) qu'avant  
✅ **Visuel**: UI claire avec bordures et couleurs distinctes  
✅ **State management**: Une seule variable d'état ajoutée  
✅ **Null-safe**: Gestion des valeurs nullables  

## 📚 Documentation

- `IMPLEMENTATION_SUBTABS_DETTES.md` - Détails technique complet
- `USER_GUIDE_SUBTABS_DETTES.md` - Guide d'utilisation pour utilisateurs
- `TECHNICAL_ARCHITECTURE_SUBTABS.md` - Architecture détaillée
- Ce fichier - Vue d'ensemble rapide

## 🔧 Fichiers Modifiés

- `mobile/lib/main.dart`
  - Ligne 183: Ajout `_debtSubTab`
  - Lignes 1254-1259: Filtre nouveau
  - Lignes 1301-1320: recentItems adapté
  - Lignes 1747-1806: UI sous-onglets nouveau

## 💡 Exemple de Flot Utilisateur

```
1. Utilisateur ouvre l'app → onglet DETTES par défaut
2. Voir liste PRÊTS (défaut) avec dettes de type 'debt'
3. Cliquer EMPRUNTS → setState(_debtSubTab = 'emprunts')
4. Rebuild() → filteredDebts ne garde que type=='loan'
5. ListView se met à jour → nouvelle liste d'emprunts s'affiche
6. Cards statistiques restent visibles pour comparaison
7. Cliquer sur PRÊTS → retour à la liste précédente
```

## 🎓 Résumé pour les Futurs Développeurs

Si vous devez modifier ce système:

1. **Variable d'état** : `_debtSubTab` (String)
2. **Valeurs valides** : `'prets'` ou `'emprunts'`
3. **Filtrage se fait** : Ligne 1254-1259 de main.dart
4. **Affichage se fait** : Lignes 1301-1320 (recentItems)
5. **UI se fait** : Lignes 1747-1806 (Row with GestureDetectors)
6. **Test** : Basculer onglets, vérifier liste change

Bon développement! 🚀
