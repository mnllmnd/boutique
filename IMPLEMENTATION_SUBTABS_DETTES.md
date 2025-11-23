# Implémentation des Sous-Onglets PRÊTS / EMPRUNTS

## Contexte
L'onglet "Dettes" a été modifié pour séparer visuellement les **Prêts** (argent prêté aux clients) des **Emprunts** (argent reçu des clients) via un système de sous-onglets interactifs.

## Modifications Effectuées

### 1. **Ajout d'une Variable d'État** (ligne 183)
```dart
String _debtSubTab = 'prets'; // 'prets' ou 'emprunts'
```
- Trace le sous-onglet actuellement sélectionné
- Valeurs possibles : `'prets'` ou `'emprunts'`
- Initialisé par défaut à `'prets'`

### 2. **Filtrage des Dettes par Type** (lignes 1254-1259)
Ajout d'une étape de filtrage dans `_buildDebtsTab()` pour appliquer le filtre du sous-onglet actif :

```dart
// Filtrer par sous-onglet actif (PRÊTS ou EMPRUNTS)
if (_debtSubTab == 'prets') {
  filteredDebts = filteredDebts.where((d) => (d['type'] ?? 'debt') == 'debt').toList();
} else if (_debtSubTab == 'emprunts') {
  filteredDebts = filteredDebts.where((d) => (d['type'] ?? 'debt') == 'loan').toList();
}
```

### 3. **Affichage Conditionnel des Récents** (lignes 1301-1320)
La liste `recentItems` affichée change selon le sous-onglet sélectionné :

- **PRÊTS** : Affiche uniquement les dettes de type `'debt'`
- **EMPRUNTS** : Affiche uniquement les dettes de type `'loan'`
- Les "autres" types (inconnus) s'affichent dans les deux onglets

### 4. **Interface des Sous-Onglets** (lignes 1747-1806)
Deux boutons interactifs ajoutés après le filtre par montant :

#### Onglet PRÊTS 🟠
- **Icône** : `Icons.trending_up` (orange)
- **Couleur active** : Orange
- **Fonction** : Affiche uniquement les prêts quand sélectionné
- Borde de soulignement orange quand actif

#### Onglet EMPRUNTS 🟣
- **Icône** : `Icons.trending_down` (purple)
- **Couleur active** : Purple
- **Fonction** : Affiche uniquement les emprunts quand sélectionné
- Borde de soulignement purple quand actif

## Fonctionnement

### Flux Utilisateur
1. L'utilisateur ouvre l'onglet "DETTES"
2. Par défaut, l'onglet **PRÊTS** est sélectionné (affiché en orange)
3. Les clients listés montrent uniquement les dettes de type `'debt'`
4. En cliquant sur l'onglet **EMPRUNTS**, l'affichage change
5. Seules les dettes de type `'loan'` sont affichées (couleur purple)
6. Les statistiques (totaux, impayées) s'affichent pour chaque section

### Intégration avec les Éléments Existants
- ✅ **Cards PRÊTS/EMPRUNTS** : Affichent toujours les totaux consolidés (non affectés par le filtre)
- ✅ **Filtre par montant** : S'applique en plus du filtre par sous-onglet
- ✅ **Recherche** : Compatible avec les deux sous-onglets
- ✅ **Clients à risque** : Affichés selon le type de dette actif

## Fichiers Modifiés
- `mobile/lib/main.dart` - Classe `_HomePageState` et fonction `_buildDebtsTab()`

## Code Sources Clés

### Variable d'État
```dart
class _HomePageState extends State<HomePage> {
  String _debtSubTab = 'prets'; // Nouveau
  // ... autres variables
}
```

### Logique de Filtrage
```dart
List filteredDebts = debts;
// ... autres filtres ...

// Filtrer par sous-onglet actif
if (_debtSubTab == 'prets') {
  filteredDebts = filteredDebts.where((d) => (d['type'] ?? 'debt') == 'debt').toList();
} else if (_debtSubTab == 'emprunts') {
  filteredDebts = filteredDebts.where((d) => (d['type'] ?? 'debt') == 'loan').toList();
}
```

### UI des Sous-Onglets
```dart
Row(
  children: [
    Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _debtSubTab = 'prets'),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: _debtSubTab == 'prets' ? Colors.orange : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          // Contenu du tab...
        ),
      ),
    ),
    // Onglet EMPRUNTS (similaire)
  ],
)
```

## Schéma Visuel

```
┌─────────────────────────────────────┐
│   ONGLET DETTES (Principal)         │
├─────────────────────────────────────┤
│                                     │
│   [PRÊTS 📈] [EMPRUNTS 📉]         │  ← Sous-onglets (NOUVEAU)
│   ════════                                
│                                     │
│   Liste des dettes (PRÊTS):         │
│   - Client A: 50 000 F              │
│   - Client B: 75 000 F              │
│                                     │
└─────────────────────────────────────┘

Lors du clic sur EMPRUNTS:

┌─────────────────────────────────────┐
│   ONGLET DETTES (Principal)         │
├─────────────────────────────────────┤
│                                     │
│   [PRÊTS] [EMPRUNTS 📉]            │  ← EMPRUNTS sélectionné
│               ═════════                
│                                     │
│   Liste des dettes (EMPRUNTS):      │
│   - Fournisseur A: 100 000 F        │
│                                     │
└─────────────────────────────────────┘
```

## Tests Recommandés

1. **Test de basculement** : Cliquer sur PRÊTS et EMPRUNTS pour voir la liste changer
2. **Test de filtrage** : Appliquer le filtre par montant sur chaque sous-onglet
3. **Test de recherche** : Chercher des clients dans les deux sous-onglets
4. **Test des statistiques** : Vérifier que les totaux des cards s'affichent correctement

## Compatibilité
- ✅ Mode sombre/clair
- ✅ Écrans de différentes tailles
- ✅ Refresh pull-to-refresh
- ✅ Tous les filtres existants
