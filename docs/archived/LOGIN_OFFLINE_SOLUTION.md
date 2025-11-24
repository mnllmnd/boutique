# 🔐 SOLUTION LOGIN OFFLINE

## Problème Identifié

❌ **Sans internet, impossible de:**
- Vérifier le mot de passe (PostgreSQL inaccessible)
- Générer JWT token (backend inaccessible)
- Première connexion (besoin du backend)

## Solution: Cache des Credentials

✅ **Après première connexion réussie:**
- Stocker phone + password hash localement
- Stocker JWT token (valide 30 jours)
- Stocker infos utilisateur (firstName, lastName, shopName)

✅ **Offline: vérifier contre le cache**
- Comparer phone
- Hash du password
- Vérifier expiration du token

---

## 🏗️ Architecture

```
┌─────────────────────────────────────┐
│      LoginPage (Flutter UI)         │
├─────────────────────────────────────┤
│  doLogin()                          │
│  ├─→ Try online (POST /auth/login)  │
│  │   ├─ Succès → Cache credentials  │
│  │   └─ Erreur → Try offline        │
│  └─→ Try offline (AuthOfflineService)
│      ├─ Validate phone + password   │
│      ├─ Check token expiry          │
│      └─ Success → Use cached token  │
├─────────────────────────────────────┤
│   AuthOfflineService                │
│   ├─ cacheCredentials()             │
│   ├─ authenticateOffline()          │
│   ├─ getCachedUserData()            │
│   ├─ getCachedToken()               │
│   └─ clearCachedCredentials()       │
├─────────────────────────────────────┤
│   SharedPreferences (Encryption)    │
│   ├─ phone                          │
│   ├─ password_hash (SHA-256 + salt) │
│   ├─ token                          │
│   ├─ token_expiry                   │
│   └─ user data (firstName, etc.)    │
└─────────────────────────────────────┘
```

---

## 📝 Fichiers Modifiés/Créés

### ✅ Créé: `lib/services/auth_offline_service.dart`
Singleton service pour gérer l'authentification offline.

**Méthodes principales:**
```dart
// Après login réussi au serveur
await AuthOfflineService().cacheCredentials(
  phone: '784666912',
  password: 'user_password',  // En clair - sera hashé
  token: 'jwt_token_from_server',
  firstName: 'John',
  lastName: 'Doe',
  shopName: 'My Shop',
  userId: 123,
);

// Pour login offline
bool success = await AuthOfflineService().authenticateOffline(
  phone: '784666912',
  password: 'user_password',
);

// Récupérer les données en cache
final userData = await AuthOfflineService().getCachedUserData();
print(userData['token']);  // JWT token

// Vérifier si on peut login offline
bool canLogin = await AuthOfflineService().hasValidCachedCredentials();
```

---

## 🔧 Intégration dans login_page.dart

### Étape 1: Importer le service
```dart
import 'services/auth_offline_service.dart';
```

### Étape 2: Modifier `doLogin()` pour supporter offline
```dart
Future doLogin() async {
  setState(() => loading = true);
  try {
    final phone = phoneCtl.text.trim();
    final password = passCtl.text;
    
    // ✨ NOUVEAU: Essayer d'abord online
    final loginSuccess = await _tryOnlineLogin(phone, password);
    
    if (!loginSuccess) {
      // ✨ NOUVEAU: Fallback offline
      final offlineSuccess = await _tryOfflineLogin(phone, password);
      
      if (!offlineSuccess) {
        await _showMinimalDialog(
          'Erreur',
          'Impossible de se connecter. Pas d\'internet et aucune session en cache.'
        );
      }
    }
  } finally {
    setState(() => loading = false);
  }
}

// ✨ NOUVEAU: Tentative online
Future<bool> _tryOnlineLogin(String phone, String password) async {
  try {
    final body = {'phone': phone, 'password': password};
    final res = await http.post(
      Uri.parse('$apiHost/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(body),
    ).timeout(const Duration(seconds: 8));

    if (res.statusCode == 200) {
      final data = json.decode(res.body);
      
      // ✨ CACHE credentials après succès
      await AuthOfflineService().cacheCredentials(
        phone: data['phone'],
        password: password,  // Stocké hashé
        token: data['auth_token'],
        firstName: data['first_name'] ?? '',
        lastName: data['last_name'] ?? '',
        shopName: data['shop_name'] ?? '',
        userId: data['id'] is int ? data['id'] : int.tryParse(data['id']) ?? 0,
      );
      
      // Initialize AppSettings
      final settings = AppSettings();
      await settings.initForOwner(data['phone']);
      await settings.setAuthToken(data['auth_token']);
      
      // Call original onLogin
      widget.onLogin(
        data['phone'],
        data['shop_name'],
        data['id'] is int ? data['id'] : int.tryParse(data['id']),
        data['first_name'],
        data['last_name'],
        data['boutique_mode_enabled'] as bool?,
      );
      
      return true;
    } else {
      print('Online login failed: ${res.statusCode}');
      return false;
    }
  } catch (e) {
    print('Online login error: $e');
    return false;
  }
}

// ✨ NOUVEAU: Fallback offline
Future<bool> _tryOfflineLogin(String phone, String password) async {
  try {
    print('Trying offline login...');
    
    // Vérifier les credentials en cache
    final isValid = await AuthOfflineService().authenticateOffline(
      phone: phone,
      password: password,
    );
    
    if (!isValid) {
      print('Offline auth failed: invalid credentials');
      return false;
    }
    
    // Récupérer les données en cache
    final userData = await AuthOfflineService().getCachedUserData();
    if (userData == null) {
      print('No cached user data');
      return false;
    }
    
    // Initialize AppSettings avec token en cache
    final settings = AppSettings();
    await settings.initForOwner(phone);
    await settings.setAuthToken(userData['token']);
    
    // Show offline indicator
    await _showMinimalDialog(
      'Mode Hors Ligne',
      'Connecté en mode hors ligne.\nLes données seront synchronisées lors du retour de la connexion.',
    );
    
    // Call onLogin
    widget.onLogin(
      phone,
      userData['shopName'],
      userData['userId'],
      userData['firstName'],
      userData['lastName'],
      null,
    );
    
    print('✅ Offline login successful');
    return true;
  } catch (e) {
    print('Offline login error: $e');
    return false;
  }
}
```

### Étape 3: Ajouter bouton "Dernier login" (optionnel)
```dart
// Dans le UI, avant le champ phone:
FutureBuilder<String?>(
  future: AuthOfflineService().getLastLoginPhone(),
  builder: (context, snapshot) {
    if (snapshot.hasData && snapshot.data != null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: OutlinedButton.icon(
          onPressed: () {
            phoneCtl.text = snapshot.data!;
          },
          icon: const Icon(Icons.history),
          label: Text('Dernier login: ${snapshot.data}'),
        ),
      );
    }
    return SizedBox.shrink();
  },
)
```

---

## 🛡️ Sécurité

### ✅ Mesures Implémentées

1. **Hash SHA-256 du password**
   - Jamais stocké en clair
   - Salt local implicite
   - Expiration du cache après 30 jours

2. **Token JWT**
   - Stocké en SharedPreferences
   - Expiré après 30 jours
   - Peut être mis à jour après sync

3. **Partitionnement**
   - Chaque utilisateur a son cache
   - Séparation par `owner_phone`
   - Nettoyage possible on logout

### ⚠️ Limitations Connues

1. **Pas de 2FA offline**
   - À ajouter si nécessaire

2. **Cache visible au déchiffrement du téléphone**
   - SharedPreferences pas chiffré par défaut
   - À ajouter si données sensibles

3. **Pas de sync des changements password**
   - Cache pas mis à jour si password changé au serveur

---

## 📊 Comparaison Online vs Offline

| Aspect | Online | Offline |
|--------|--------|---------|
| **Login** | ✅ Vérification BD | ✅ Vérification cache |
| **Token** | ✅ Généré serveur | ✅ Utilise cache |
| **Sync** | ✅ Toujours à jour | ❌ Pas de sync |
| **Données** | ✅ Fraîches | ✅ En cache |
| **Créer dettes** | ✅ Direct serveur | ✅ Queue Hive |
| **Modifier dettes** | ✅ Direct serveur | ✅ Queue Hive |
| **Latence** | 200-500ms | <1ms |

---

## 🔄 Flux Complet (Online → Offline → Online)

```
1️⃣ ONLINE LOGIN
   User: 784666912 / password123
   ↓
   Backend verifies → OK
   ↓
   Response: {"token": "jwt...", "auth_token": "..."}
   ↓
   AuthOfflineService.cacheCredentials() saves:
   - phone: 784666912
   - password_hash: sha256("password123" + salt)
   - token: jwt...
   - expiry: now + 30 days
   ↓
   App initialized ✅

2️⃣ OFFLINE (internet lost)
   User creates debt
   ↓
   HiveService saves to local cache
   ↓
   SyncQueue queues operation
   ↓
   User logout → tries re-login
   ↓
   Backend unreachable → try offline
   ↓
   AuthOfflineService.authenticateOffline():
   - Check phone matches cache
   - Hash password & compare
   - Check token not expired
   ✓ All OK → Use cached token ✅

3️⃣ RECONNECT (internet back)
   User still in app OR re-login
   ↓
   HiveService detects online
   ↓
   Auto-sync triggered
   ↓
   Queue operations synced
   ↓
   Token refreshed from server
   ↓
   Cache updated with new token ✅
```

---

## 🧪 Testing Checklist

- [ ] Login online → cache saved
- [ ] Logout → cache persists
- [ ] Kill app → cache persists
- [ ] Restart app, offline → login using cache
- [ ] Wrong password offline → login fails
- [ ] Wrong phone offline → login fails
- [ ] Token expired → clear cache
- [ ] Create debt offline → queued
- [ ] Reconnect → sync queued debts
- [ ] Token refreshed after sync

---

## 📝 Exemple Complet d'Utilisation

```dart
// LOGIN PAGE
class LoginPage extends StatefulWidget {
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  Future doLogin() async {
    try {
      // 1. Try online
      final onlineSuccess = await _tryOnlineLogin(phone, password);
      if (onlineSuccess) return;
      
      // 2. Try offline
      final offlineSuccess = await _tryOfflineLogin(phone, password);
      if (offlineSuccess) return;
      
      // 3. Both failed
      showErrorDialog('Login failed');
    } catch (e) {
      showErrorDialog('Error: $e');
    }
  }
  
  Future<bool> _tryOnlineLogin(String phone, String password) async {
    try {
      // POST /auth/login
      // On success: AuthOfflineService().cacheCredentials(...)
      // On failure: return false
    } catch (e) {
      return false;
    }
  }
  
  Future<bool> _tryOfflineLogin(String phone, String password) async {
    final isValid = await AuthOfflineService().authenticateOffline(
      phone: phone,
      password: password,
    );
    if (!isValid) return false;
    
    final userData = await AuthOfflineService().getCachedUserData();
    // Use userData['token'] for AppSettings
    return true;
  }
}

// MAIN.DART
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Check if user already cached and can login offline
  _checkAutoLogin();
  
  runApp(const MyApp());
}

Future<void> _checkAutoLogin() async {
  final hasValid = await AuthOfflineService().hasValidCachedCredentials();
  if (hasValid) {
    print('✅ User can auto-login offline');
  }
}
```

---

## ✅ Résumé

### Avec cette solution:
1. ✅ **Premier login**: Nécessite online (normal)
2. ✅ **Login suivants**: Possible offline si cache valide
3. ✅ **Données**: Créées offline, synced après reconnexion
4. ✅ **Sécurité**: Password hashé, token expiré
5. ✅ **Expérience**: Seamless transition online ↔ offline

### Non couvert:
1. ❌ Chiffrement cache (SharedPreferences)
2. ❌ 2FA offline
3. ❌ Sync password changes
4. ❌ Biometric unlock (à ajouter)

---

**Status**: ✅ Ready to implement  
**Complexity**: Medium  
**Time to implement**: 1-2 hours
