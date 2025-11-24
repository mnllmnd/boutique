# Guide Complet: Exécution des Tests End-to-End Hive + PostgreSQL

## 📋 Table des matières

1. [Prérequis](#prérequis)
2. [Setup Backend](#setup-backend)
3. [Exécution des Tests](#exécution-des-tests)
4. [Monitoring et Débogage](#monitoring-et-débogage)
5. [Troubleshooting](#troubleshooting)

---

## Prérequis

### Environnement Local

```bash
# Flutter/Dart
flutter --version     # Minimum 3.0.0

# Node.js & PostgreSQL
node --version        # Minimum 14.0.0
npm --version         # Minimum 6.0.0
psql --version        # PostgreSQL 12+

# Bash (pour le script test_hive_e2e.sh)
bash --version        # 4.0+
```

### Vérifier l'installation

```bash
# Depuis le répertoire du projet
flutter doctor

# Expected output:
# Doctor summary (to see all details, run flutter doctor -v):
# [✓] Flutter
# [✓] Dart
# [✓] Android toolchain
# [✓] Xcode
# [✓] Android Studio
```

---

## Setup Backend

### Étape 1: Démarrer PostgreSQL

```bash
# Windows
# Assurez-vous que le service PostgreSQL est en cours d'exécution

# Vérifier la connexion
psql -U postgres -h localhost

# Si erreur, redémarrer le service:
# Services.msc → PostgreSQL → Redémarrer
```

### Étape 2: Initialiser la Base de Données

```bash
cd backend

# Créer la base de données
npm run migrate

# Expected output:
# ✅ Database initialized
# ✅ Tables created
# ✅ Migrations applied
```

### Étape 3: Démarrer le Backend

```bash
cd backend

# Terminal 1
npm start

# Expected output:
# ✅ Server started on http://localhost:3000
# ✅ PostgreSQL connected
# ✅ Health check passed
```

### Étape 4: Vérifier que l'API est disponible

```bash
# Terminal 2
curl -i http://localhost:3000/health

# Expected:
# HTTP/1.1 200 OK
# {"status": "ok"}
```

---

## Exécution des Tests

### Méthode 1: Tests Bash (API REST directement)

```bash
# Terminal 3
cd /c/Users/bmd-tech/Desktop/Boutique

# Rendre le script exécutable
chmod +x test_hive_e2e.sh

# Exécuter le test
./test_hive_e2e.sh

# Expected output:
# === Hive + PostgreSQL End-to-End Test ===
# ✅ API disponible à http://localhost:3000
# 📋 Créer un client de test
# ✅ Client créé avec ID: 1
# 📋 Créer une dette de test
# ✅ Dette créée avec ID: 100
# 📋 Ajouter un paiement à la dette
# ✅ Paiement créé avec ID: 200
# 📋 Ajouter une addition à la dette
# ✅ Addition créée avec ID: 300
# 📋 Vérifier les données sur le serveur
# ✅ Clients trouvés: 1
# ✅ Dettes trouvées: 1
# ✅ Paiements trouvés: 1
# ✅ Additions trouvées: 1
# ✅ Test end-to-end réussi!
```

### Méthode 2: Tests Flutter (Intégration avec Hive)

```bash
# Terminal 4
cd /c/Users/bmd-tech/Desktop/Boutique/mobile

# Exécuter les tests d'intégration Hive
flutter test test/hive_integration_test.dart -v

# Expected output:
# ✅ Test 1: Create and Cache Debt
# ✅ Test 2: Multiple Debts Cache
# ✅ Test 3: Add Payment and Track
# ✅ Test 4: Client Caching
# ✅ Test 5: Debt Additions Tracking
# ✅ Test 6: Sync Status Initialization
# ✅ Test 7: Online Status Tracking
# 
# All tests passed! (7/7)
```

### Méthode 3: Tests End-to-End (Complets)

```bash
# Terminal 5
cd /c/Users/bmd-tech/Desktop/Boutique/mobile

# Exécuter les tests end-to-end Hive + PostgreSQL
flutter test test/hive_e2e_test.dart -v

# Expected output:
# === Hive E2E Synchronization Tests ===
# 
# ✅ Test 1: Create, Cache, and Sync Debt
#   Step 1: Creating client locally
#     ✅ Client saved locally
#   Step 2: Creating debt locally
#     ✅ Debt saved locally with sync status: pending
#   Step 3: Verifying debt is cached
#     ✅ Debt found in cache (1 debts)
#   Step 4: Checking sync status
#     ✅ Sync status retrieved
#   Step 5: Triggering manual sync
#     ✅ Sync triggered
#   Step 6: Checking sync results
#     ✅ Sync completed
# ✅ Test 1 passed: Create, Cache, and Sync Debt
#
# ✅ Test 2: Offline Queue and Auto-Sync
# ✅ Test 3: Payment Tracking and Balance Update
# ✅ Test 4: Debt Additions Tracking
# ✅ Test 5: Conflict Resolution (Last-Write-Wins)
# ✅ Test 6: Sync Status Monitoring
# ✅ Test 7: Comprehensive Multi-Entity Sync
#
# All tests passed! (7/7)
```

---

## Monitoring et Débogage

### Logs du Backend

```bash
# Terminal 1 (Backend)
npm start

# Observe les logs de chaque opération:
# [2024-01-15 10:30:45] POST /debts (201)
# [2024-01-15 10:30:46] POST /payments (201)
# [2024-01-15 10:30:47] GET /debts (200)
```

### Logs du Flutter (Hive)

```bash
# Terminal 5 (Flutter Tests)
flutter test test/hive_e2e_test.dart -v

# Les logs de HiveService sont imprimés:
# 📋 [HiveService] Initializing for owner: +33123456789
# 📋 [HiveService] Cache initialized
# 📋 [HiveService] Auto-sync timer started
# 📋 [HiveService] Syncing with server...
# ✅ [HiveService] Sync completed successfully
```

### Inspection de la Base de Données

```bash
# Terminal 6
psql -U postgres -d boutique

# Vérifier les clients
SELECT * FROM clients WHERE owner_phone = '+33123456789';

# Vérifier les dettes
SELECT * FROM debts WHERE owner_phone = '+33123456789';

# Vérifier les paiements
SELECT * FROM payments WHERE debt_id = 100;

# Vérifier les additions
SELECT * FROM debt_additions WHERE debt_id = 100;
```

### Monitoring en Temps Réel

```bash
# Terminal 7
# Utiliser une interface de monitoring (optionnel)

# Ou utiliser pgAdmin (interface web pour PostgreSQL)
# URL: http://localhost:5050
# Email: admin@admin.com
# Password: admin
```

---

## Troubleshooting

### Problème 1: "API non disponible"

```
Erreur:
❌ API non disponible à http://localhost:3000

Solution:
1. Vérifier que le backend est démarré (npm start)
2. Vérifier que le port 3000 est libre
3. Vérifier que PostgreSQL est connecté

# Vérifier le port
lsof -i :3000

# Arrêter le processus qui utilise le port
kill -9 <PID>

# Redémarrer le backend
npm start
```

### Problème 2: "Binding has not yet been initialized"

```
Erreur dans Flutter tests:
Flutter binding was not initialized when HiveService.init() was called

Solution:
✅ DÉJÀ FIXÉ: TestWidgetsFlutterBinding.ensureInitialized() ajouté au test

Vérifier dans test/hive_e2e_test.dart:
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();  // Cette ligne est présente
  ...
}
```

### Problème 3: "Connection timeout"

```
Erreur lors de la sync:
timeout: Failed to connect to server

Solution:
1. Vérifier que l'API backend est accessible
2. Vérifier le timeout dans HiveService (actuellement 10 secondes)
3. Vérifier la connexion réseau

# Augmenter le timeout si nécessaire
# Dans hive_service.dart, changer:
final duration = Duration(seconds: 30);  // Au lieu de 10
```

### Problème 4: "Null reference in SyncQueue"

```
Erreur:
null reference when accessing 'syncStatus'

Solution:
1. Vérifier que HiveServiceManager a été initialisé
2. Vérifier que le ownerPhone est correct

# Vérifier l'initialisation:
await HiveServiceManager().initializeForOwner('+33123456789');

# Vérifier le ownerPhone dans tous les tests
```

### Problème 5: "Débts non trouvés après sync"

```
Erreur:
Debt not found in cache after sync

Solution:
1. Vérifier que la sync s'est complétée
2. Vérifier que l'ownerPhone est cohérent
3. Vérifier les logs du serveur

# Ajouter un délai si nécessaire
await Future.delayed(Duration(seconds: 2));
final cachedDebts = await HiveIntegration.getDebts(ownerPhone);
```

### Problème 6: "Permission denied" (Bash script)

```
Erreur:
./test_hive_e2e.sh: Permission denied

Solution:
# Rendre le script exécutable
chmod +x test_hive_e2e.sh

# Ou exécuter directement avec bash
bash test_hive_e2e.sh
```

---

## Scénarios de Test Complets

### Scénario 1: Offline → Queue → Sync

```bash
# Étape 1: Arrêter l'API backend
# Étape 2: Créer des dettes (flutter test)
# Étape 3: Vérifier qu'elles sont en queue (syncStatus: pending)
# Étape 4: Redémarrer l'API backend
# Étape 5: Vérifier la sync automatique
# Résultat: Dettes synchronisées au serveur
```

### Scénario 2: Conflit de Modification Concurrente

```bash
# Étape 1: Créer une dette (ID: 100)
# Étape 2: Modifier localement (amount: 200)
# Étape 3: Modifier sur le serveur (amount: 150) - plus tard
# Étape 4: Sync
# Résultat: Version serveur gagne (last-write-wins)
```

### Scénario 3: Paiements Multiples + Additions

```bash
# Étape 1: Créer une dette (amount: 500)
# Étape 2: Ajouter 5 paiements (50 chacun)
# Étape 3: Ajouter 3 additions (100 chacun)
# Étape 4: Vérifier le solde final (500 - 250 + 300 = 550)
# Étape 5: Sync avec le serveur
# Résultat: Tous les calculs sont corrects
```

### Scénario 4: Performance avec 1000+ Dettes

```bash
# Étape 1: Créer 1000 dettes localement (en loop)
# Étape 2: Mesurer le temps de cache (getDebts)
# Étape 3: Trigger sync avec 1000 dettes
# Étape 4: Mesurer le temps de sync
# Expected: Cache <5ms, Sync <2s

# Résultats attendus:
# - Cache hit: <1ms
# - Sync 100 items: 50-100ms
# - Sync 1000 items: 500-1000ms
# - Conflict resolution: <10ms per item
```

---

## Résumé du Flux de Test

```
┌─────────────────────────────────────────────┐
│        START TEST ENVIRONMENT               │
│  1. PostgreSQL running (port 5432)          │
│  2. Backend API running (port 3000)         │
│  3. Flutter SDK available                   │
└─────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────┐
│       BASH API TESTS (test_hive_e2e.sh)    │
│  - Create clients                           │
│  - Create debts                             │
│  - Add payments                             │
│  - Verify on server                         │
│  - Test conflict resolution                 │
└─────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────┐
│   FLUTTER HIVE TESTS (hive_integration_test)│
│  - Local caching                            │
│  - Payment tracking                         │
│  - Debt additions                           │
│  - Sync status                              │
│  - Online detection                         │
└─────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────┐
│     FLUTTER E2E TESTS (hive_e2e_test)      │
│  - Create → Cache → Sync cycle              │
│  - Offline queue management                 │
│  - Multi-entity sync                        │
│  - Conflict resolution                      │
│  - Balance calculation                      │
│  - Sync monitoring                          │
└─────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────┐
│         ✅ ALL TESTS PASSED                 │
│  - System ready for production              │
│  - Hive integration verified                │
│  - PostgreSQL sync working                  │
│  - Offline capability confirmed             │
└─────────────────────────────────────────────┘
```

---

## Checklist de Validation Finale

- [ ] PostgreSQL démarré et accessible
- [ ] Backend API running à http://localhost:3000
- [ ] `test_hive_e2e.sh` exécuté avec succès (7/7 ✅)
- [ ] `flutter test hive_integration_test.dart` (7/7 ✅)
- [ ] `flutter test hive_e2e_test.dart` (7/7 ✅)
- [ ] Dettes créées visibles dans pgAdmin
- [ ] Sync logs visibles dans le backend
- [ ] Tests de conflits résolu correctement
- [ ] Performance acceptable (<2s pour 1000 dettes)
- [ ] Documentation mise à jour
- [ ] Prêt pour la production ✨

---

## Commandes Rapides

```bash
# Démarrer tout rapidement
cd backend && npm start &
sleep 2
cd ../mobile && flutter test test/hive_e2e_test.dart -v

# Vérifier tout est ok
curl -i http://localhost:3000/health
psql -U postgres -d boutique -c "SELECT COUNT(*) FROM debts;"
flutter test test/hive_e2e_test.dart --coverage

# Nettoyer les données de test
psql -U postgres -d boutique << EOF
DELETE FROM debt_additions WHERE debt_id > 99;
DELETE FROM payments WHERE debt_id > 99;
DELETE FROM debts WHERE id > 99;
DELETE FROM clients WHERE id > 99;
EOF
```

---

## Prochaines Étapes

1. ✅ **Tests en cours**: Vérifier tous les tests passent
2. ⏳ **Intégration**: Ajouter HiveServiceManager à main.dart
3. ⏳ **Production**: Déployer avec des vrais données
4. ⏳ **Monitoring**: Mettre en place Sentry pour les erreurs
5. ⏳ **Performance**: Tester avec 10000+ dettes

---

**Dernière mise à jour**: 2024-01-15
**Statut**: ✅ Prêt pour tester
**Version**: 1.0 (E2E Tests Complete)
