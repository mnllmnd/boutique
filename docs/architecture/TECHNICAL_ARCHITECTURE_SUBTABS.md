# Architecture Technique - Système de Sous-Onglets PRÊTS/EMPRUNTS

## 🏗️ Structure Générale

### Hiérarchie de Widgets
```
HomePage (StatefulWidget)
│
├─ _HomePageState (State)
│  │
│  ├─ Variable d'état: _debtSubTab
│  │
│  ├─ _buildDebtsTab() → RefreshIndicator
│  │  │
│  │  └─ ListView.builder
│  │     │
│  │     ├─ Item 0: Header
│  │     │  ├─ Cards statistiques (PRÊTS/EMPRUNTS/IMPAYÉES)
│  │     │  ├─ Filtre par montant
│  │     │  └─ Sous-onglets (PRÊTS | EMPRUNTS) ← NOUVEAU
│  │     │
│  │     ├─ Items 1..N: Liste des dettes filtrées
│  │     │
│  │     └─ Item N+1: Clients à risque
│  │
│  └─ _buildClientsTab() → [Clients]
```

## 🔄 Flux de Données

### 1. Initialisation
```
initState()
  ├─ _debtSubTab = 'prets' (défaut)
  ├─ fetchClients()
  ├─ fetchDebts()
  └─ _startConnectivityListener()
```

### 2. Rendu (build)
```
_buildDebtsTab()
  │
  ├─ Charger debts depuis liste locale
  │
  ├─ Appliquer filtres:
  │  ├─ Filtre montant (min/max)
  │  └─ Filtre type: _debtSubTab == 'prets' ? 'debt' : 'loan'
  │
  ├─ Grouper par client|type
  │
  ├─ Trier par montant et status
  │
  ├─ Préparer recentItems selon _debtSubTab
  │
  └─ Retourner ListView.builder avec items
```

### 3. Interaction Utilisateur
```
Utilisateur clique sur "EMPRUNTS"
  │
  └─ GestureDetector.onTap()
     └─ setState(() => _debtSubTab = 'emprunts')
        └─ Rebuild _buildDebtsTab()
           └─ Nouvelle liste avec type=='loan'
```

## 📊 Données et Types

### Structure d'une Dette
```dart
{
  'id': int,
  'client_id': int,
  'name': String,
  'amount': double,
  'remaining': double,
  'type': String,          // ← 'debt' ou 'loan'
  'date': String,
  'payments': List,
  ...
}
```

### Variable d'État _debtSubTab
```dart
String _debtSubTab = 'prets';
// Valeurs possibles:
// - 'prets'   : Affiche type == 'debt'
// - 'emprunts': Affiche type == 'loan'
```

## 🔍 Logique de Filtrage

### Étape 1: Filtrer par Montant
```dart
List filteredDebts = debts;
if (_minDebtAmount > 0 || _maxDebtAmount > 0) {
  filteredDebts = debts.where((d) {
    final remaining = (d['remaining'] as double?) ?? 0.0;
    bool inRange = true;
    if (_minDebtAmount > 0 && remaining < _minDebtAmount) inRange = false;
    if (_maxDebtAmount > 0 && remaining > _maxDebtAmount) inRange = false;
    return inRange;
  }).toList();
}
```

### Étape 2: Filtrer par Sous-Onglet (NOUVEAU)
```dart
if (_debtSubTab == 'prets') {
  filteredDebts = filteredDebts.where((d) => 
    (d['type'] ?? 'debt') == 'debt'
  ).toList();
} else if (_debtSubTab == 'emprunts') {
  filteredDebts = filteredDebts.where((d) => 
    (d['type'] ?? 'debt') == 'loan'
  ).toList();
}
```

### Étape 3: Grouper et Trier
```dart
Map<String, List> grouped = {};
// Grouper par "clientId|type"

List<MapEntry<String, List>> groups = grouped.entries.toList();
// Trier: dettes impayées d'abord, puis montant décroissant
```

### Étape 4: Séparer et Afficher selon Sous-Onglet
```dart
final prets = groups.where((e) => e.key.endsWith('|debt')).toList();
final emprunts = groups.where((e) => e.key.endsWith('|loan')).toList();

List<dynamic> recentItems = [];
if (_debtSubTab == 'prets') {
  recentItems.addAll(prets);
} else if (_debtSubTab == 'emprunts') {
  recentItems.addAll(emprunts);
}
```

## 🎨 UI Composants

### Sous-Onglets (TabBar Style)
```dart
Row(
  children: [
    // PRÊTS Tab
    Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _debtSubTab = 'prets'),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: _debtSubTab == 'prets' ? Colors.orange : transparent,
                width: 2,
              ),
            ),
          ),
          child: Column(
            children: [
              Icon(Icons.trending_up, 
                   color: _debtSubTab == 'prets' ? Colors.orange : secondary),
              Text('PRÊTS',
                   style: TextStyle(
                     color: _debtSubTab == 'prets' ? Colors.orange : secondary,
                   )),
            ],
          ),
        ),
      ),
    ),
    // EMPRUNTS Tab (similaire avec Colors.purple)
  ],
)
```

## 🔄 Cycle de Vie

### Quand _debtSubTab Change
1. **setState()** est appelé
2. **_buildDebtsTab()** est relancée
3. **filteredDebts** est recalculée avec le nouveau filtre
4. **recentItems** est repopulée
5. **ListView.builder** se met à jour
6. UI affiche la nouvelle liste

## 📈 Performance

### Optimisations
- ✅ Filtrage en cascade (montant → type)
- ✅ Groupement une fois par build
- ✅ Tri une fois par build
- ✅ ListView.builder (lazy loading)
- ✅ Pas de rebuild du parent HomePage

### Complexité
- **Filtrage montant** : O(n)
- **Filtrage type** : O(n)
- **Groupement** : O(n)
- **Tri** : O(n log n)
- **Total** : O(n log n) par build

## 🐛 Gestion d'Erreurs

### Valeurs Nullables
```dart
(d['type'] ?? 'debt')      // Default à 'debt' si null
(d['remaining'] ?? 0.0)    // Default à 0 si null
(d['client_id'] ?? 'unknown') // Default à 'unknown' si null
```

### Dettes Vides
- Si `filteredDebts` est vide → recentItems est vide
- ListView affiche quand même le header
- "RÉCENT" section vide
- "CLIENTS À RISQUE" hidden si aucun impayé

## 🔐 Sécurité

- ✅ Validation des types (type == 'debt' ou 'loan')
- ✅ Null safety pour tous les accès
- ✅ Pas d'accès direct à _debtSubTab en dehors de setState()
- ✅ Pas de données sensibles dans UI

## 📝 Fichiers Modifiés

```
mobile/
├─ lib/
│  └─ main.dart
│     ├─ _HomePageState (ligne 180)
│     │  └─ String _debtSubTab = 'prets'; ← NOUVEAU
│     │
│     └─ _buildDebtsTab() (ligne 1226)
│        ├─ Lignes 1254-1259: Filtre type nouveau
│        ├─ Lignes 1301-1320: recentItems conditionnel
│        └─ Lignes 1747-1806: UI Sous-onglets NOUVEAU
│
├─ IMPLEMENTATION_SUBTABS_DETTES.md ← NOUVEAU
└─ USER_GUIDE_SUBTABS_DETTES.md ← NOUVEAU
```

## 🧪 Points de Test

1. **Basculement d'onglets**
   - Clic sur PRÊTS → liste change
   - Clic sur EMPRUNTS → liste change

2. **Filtrage combiné**
   - Montant min/max + Sous-onglet PRÊTS
   - Montant min/max + Sous-onglet EMPRUNTS

3. **Persistance d'état**
   - Scroll + bascule onglet + scroll back
   - Vérifier que liste est correcte

4. **Données nullables**
   - Dettes sans type défini
   - Clients sans montant

5. **Performance**
   - 1000+ dettes
   - Basculement onglets rapide
