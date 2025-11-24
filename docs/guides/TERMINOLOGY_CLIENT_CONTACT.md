# Système de Terminologie Dynamique : CLIENT / CONTACT

## 📋 Vue d'Ensemble

L'application utilise désormais un système de terminologie **dynamique** qui change selon le mode boutique :

- **Mode Boutique ACTIVÉ** ✅ → Utilise le terme **CLIENT**
- **Mode Boutique DÉSACTIVÉ** ❌ → Utilise le terme **CONTACT**

## 🔧 Implémentation Technique

### Fonctions Helper

Deux fonctions helper ont été créées pour gérer la terminologie :

```dart
// Retourne 'client' ou 'contact' (minuscule)
String _getTermClient() {
  return AppSettings().boutiqueModeEnabled ? 'client' : 'contact';
}

// Retourne 'CLIENT' ou 'CONTACT' (majuscule)
String _getTermClientUp() {
  return AppSettings().boutiqueModeEnabled ? 'CLIENT' : 'CONTACT';
}
```

### Utilisation dans le Code

Les textes UI utilisent maintenant ces fonctions au lieu de chaînes codées en dur :

**Avant :**
```dart
Text('CLIENTS', style: TextStyle(...))
title: const Text('Supprimer le client'),
Text('Ajouter client', style: TextStyle(...))
```

**Après :**
```dart
Text(_getTermClientUp(), style: TextStyle(...))
title: Text('Supprimer le ${_getTermClient()}'),
Text('Ajouter ${_getTermClient()}', style: TextStyle(...))
```

## 🎯 Endroits Modifiés

### 1. **Onglet Principal (Bottom Navigation)**
- Texte: `CLIENTS` ↔ `CONTACTS`

### 2. **Messages de Suppression**
- Titre: `Supprimer le client` ↔ `Supprimer le contact`
- Contenu: `Voulez-vous vraiment supprimer ce client ?` ↔ `Voulez-vous vraiment supprimer ce contact ?`

### 3. **Actions Menu**
- Menu contexte: `Supprimer client` ↔ `Supprimer contact`

### 4. **Dialogs**
- Aucun client: `Aucun client trouvé` ↔ `Aucun contact trouvé`
- Bouton: `Ajouter client` ↔ `Ajouter contact`

### 5. **Messages de Succès**
- `Client supprimé` ↔ `Contact supprimé`

### 6. **Textes par Défaut**
- Quand pas de nom: `Client` ↔ `Contact`
- Client inconnu: `Client inconnu` ↔ `Contact inconnu`

### 7. **Section Risque**
- Titre: `CLIENTS À RISQUE` ↔ `CONTACTS À RISQUE`
- Défaut: `Clients inconnus` ↔ `Contacts inconnus`

## 🔄 Fonctionnement

### Quand le Mode Boutique Change

1. L'utilisateur accède à **PARAMÈTRES**
2. Il active/désactive le **MODE BOUTIQUE**
3. À la prochaine ouverture de l'onglet CLIENTS, la terminologie change automatiquement

### Réactivité

- Les textes utilisant `_getTermClient()` se mettent à jour dynamiquement
- Pas besoin de redémarrer l'app
- La terminologie s'ajuste en temps réel

## 💡 Avantages

✅ **Une seule source de vérité** - Les termes sont centralisés
✅ **Flexibilité** - Facile à changer sans chercher tous les endroits
✅ **Cohérence** - Tous les textes utilisent les mêmes fonctions
✅ **Maintenabilité** - Ajouter un nouveau terme requiert juste une modification
✅ **Localisation** - Prêt pour supporter d'autres langues

## 🚀 Extensions Futures

Si vous voulez ajouter plus de termes dynamiques :

```dart
// Exemple pour d'autres termes
String _getTermDebt() {
  return AppSettings().boutiqueModeEnabled ? 'dette' : 'crédit';
}

String _getTermPayment() {
  return AppSettings().boutiqueModeEnabled ? 'paiement' : 'remboursement';
}
```

Puis utiliser partout :
```dart
Text('Ajouter ${_getTermPayment()}', ...)
```

## 📍 Endroits où Chercher les Nouvelles Occurrences

Si vous trouvez d'autres textes liés aux clients :

1. Chercher : `'CLIENT` ou `"CLIENT`
2. Chercher : `'client` ou `"client`
3. Chercher : `'CLIENTS` ou `"CLIENTS`
4. Chercher : `'clients` ou `"clients`

Puis remplacer par les fonctions helper appropriées.

## ✅ Fichiers Modifiés

### 1. `mobile/lib/main.dart`
- Ajout de `_getTermClient()` (ligne ~959)
- Ajout de `_getTermClientUp()` (ligne ~963)
- Remplacement de ~10 occurrences de textes CLIENT/CONTACT
- Adaptation des messages dynamiques dans :
  - Onglet CLIENTS → _getTermClientUp()
  - Dialogs de suppression/ajout
  - Messages de succès
  - Sections "Clients à risque"

### 2. `mobile/lib/debt_details_page.dart`
- Ajout d'import : `import 'app_settings.dart';` (ligne 11)
- Ajout de `_getTermClient()` (ligne ~80)
- Ajout de `_getTermClientUp()` (ligne ~84)
- Remplacement de 3 occurrences :
  - Avatar default: `(AppSettings().boutiqueModeEnabled ? 'Client' : 'Contact')`
  - Subtitle sous l'avatar : `_getTermClient()`
  - Tous les textes affichés à l'utilisateur

## 🔍 Validation

Pour vérifier que tout fonctionne :

1. Ouvrir Settings → MODE BOUTIQUE → ACTIVÉ
2. Onglet CLIENTS → Doit afficher "CLIENTS"
3. Aller dans Settings → MODE BOUTIQUE → DÉSACTIVÉ
4. Retourner à l'onglet → Doit afficher "CONTACTS"
5. Essayer les dialogs (supprimer, ajouter) → Termes adaptés

---

**Note** : Les noms des variables internes (`clients`, `client_id`) restent inchangés pour garder la compatibilité avec le backend et la base de données.
