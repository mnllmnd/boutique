# 🔧 Dev Auto-Login & Token Persistence

## Problème résolu
- ✅ Les tokens ne se perdent plus à chaque redémarrage en développement
- ✅ Plus besoin de créer de nouveaux comptes constamment
- ✅ Auto-login automatique avec les credentials du dernier login
- ✅ Seed automatique du compte test en cas de besoin

## Comment ça marche

### Architecture
```
Frontend (Flutter Web/Mobile)
    ↓
DevAutoLoginService
    ├─ Essaie d'auto-login en mode dev (web)
    ├─ Récupère les credentials en cache
    ├─ Seed le compte test automatiquement si nécessaire
    └─ Retourne les données utilisateur
    ↓
Backend (Node.js)
    └─ /auth/seed-dev-account (nouveau endpoint)
```

### En développement (kIsWeb = true)

1. **Au démarrage de l'app** :
   ```dart
   // main.dart: _loadOwner()
   if (kIsWeb) {
     final devService = DevAutoLoginService();
     final devLoginResult = await devService.tryAutoLoginDev();
     // ✅ Auto-login si credentials en cache
   }
   ```

2. **Récupère les credentials en cache** :
   - `pin_auth_offline_phone`
   - `pin_auth_offline_token`
   - `pin_auth_offline_user_id`
   - Autres données utilisateur

3. **Si pas de cache** :
   - Appelle `/auth/seed-dev-account` pour créer le compte test
   - Hash : `DE_PHONE = '784666912'`, `DEV_PIN = '1234'`
   - Met en cache automatiquement

### En production (kIsWeb = false)
- L'endpoint `/auth/seed-dev-account` retourne 403 (vérification `NODE_ENV`)
- Comportement normal : demande de login manuel

## Utilisation

### Compte de test automatique
```
Phone: 784666912
PIN: 1234
Nom: Dev Test
Shop: Test Shop
```

### Activation en mode dev
```dart
// Optionnel - active explicitement le mode dev
final devService = DevAutoLoginService();
await devService.setDevModeEnabled(true);
```

### Réinitialiser les credentials dev
```dart
// Efface les credentials cachés
final devService = DevAutoLoginService();
await devService.clearDevCredentials();

// Puis redémarrer l'app pour reseed
```

### Vérifier le mode dev
```dart
final devService = DevAutoLoginService();
final isDevMode = await devService.isDevModeEnabled();
print(isDevMode ? '🔧 Dev mode' : '🔒 Production');
```

## Flux de développement optimal

### Première utilisation (web)
```
1. Démarrer l'app Flutter web
2. DevAutoLoginService détecte kIsWeb=true et mode dev
3. Aucune credential en cache → appelle /auth/seed-dev-account
4. Backend crée le compte 784666912 avec PIN 1234
5. Frontend cache le token reçu
6. ✅ Auto-login réussi, accès instantané
```

### Utilisation ultérieure (web)
```
1. Redémarrer l'app
2. DevAutoLoginService retrouve le token en cache
3. Vérifie le token avec /auth/verify-token (optionnel)
4. ✅ Auto-login imédiat, zéro input
```

### Sur mobile/Android (kIsWeb = false)
```
1. Mode dev désactivé automatiquement
2. Comportement normal : login requis
3. Une fois logué, token persiste et auto-login fonctionne
```

## Avantages

| Avant | Après |
|-------|-------|
| ❌ Token perdu à chaque redémarrage | ✅ Token persistant en cache |
| ❌ Obligé de créer un compte à chaque fois | ✅ Compte test seed automatique |
| ❌ Plusieurs minutes de setup par redémarrage | ✅ Auto-login instantané |
| ❌ Perte de contexte entre dev sessions | ✅ État conservé entre redémarrages |

## Code clé

### DevAutoLoginService
```dart
// Activation du mode dev (web seulement)
Future<bool> isDevModeEnabled() async {
  return prefs.getBool('dev_mode_enabled') ?? kIsWeb;
}

// Auto-login avec credentials en cache
Future<Map<String, dynamic>?> tryAutoLoginDev() async {
  // 1. Récupère les credentials en cache
  // 2. Vérifie le token (optionnel)
  // 3. Ou seed un nouveau compte
  // 4. Met en cache et retourne
}

// Seed du compte test
Future<Map<String, dynamic>?> _seedDevAccount() async {
  final seedRes = await http.post(
    '$apiHost/auth/seed-dev-account',
    body: jsonEncode({
      'phone': '784666912',
      'pin': '1234',
      ...
    })
  );
  // Retourne le token et les données utilisateur
}
```

### Backend Endpoint
```javascript
// POST /auth/seed-dev-account (dev seulement)
router.post('/seed-dev-account', async (req, res) => {
  // Vérifier NODE_ENV !== 'production'
  // Créer ou régénérer le compte
  // Retourner le token
});
```

## Notes de sécurité

- ✅ `/auth/seed-dev-account` **bloqué en production** (NODE_ENV check)
- ✅ PIN hashé avec bcrypt même en dev
- ✅ Token unique généré à chaque seed
- ✅ Credentials stockés seulement sur le device local (SharedPreferences)
- ✅ Token a une durée de 30 jours

## Troubleshooting

### Token non trouvé après redémarrage
```
1. Vérifier: kIsWeb === true (mode dev détecté)
2. Vérifier: DevAutoLoginService.isDevModeEnabled() === true
3. Redémarrer l'app (force la ré-initialisation)
4. Appeler: clearDevCredentials() puis redémarrer
```

### Seed échoue avec 403
```
✅ Attendu en production (NODE_ENV='production')
❌ En dev, vérifier: NODE_ENV !== 'production'
```

### Auto-login ne fonctionne pas sur Android
```
✅ Attendu (kIsWeb = false, mode dev désactivé)
Utiliser le login normal PIN pour la première connexion
Token persiste ensuite automatiquement
```

## Développement futur

- [ ] UI toggle pour activer/désactiver le mode dev
- [ ] Dashboard des modes debug/dev dans settings
- [ ] Synchronisation multi-comptes en cache
- [ ] Export/import de sessions dev
