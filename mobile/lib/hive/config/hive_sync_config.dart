import 'dart:math';

/// Configuration pour la synchronisation Hive + PostgreSQL
/// Ce fichier contient tous les paramètres de configuration de sync

class HiveSyncConfig {
  // ============= Timing =============
  /// Intervalle d'auto-sync en secondes
  static const int AUTO_SYNC_INTERVAL_SECONDS = 300; // 5 minutes

  /// Timeout pour une requête de sync en secondes
  static const int SYNC_REQUEST_TIMEOUT_SECONDS = 30;

  /// Délai avant de relancer un auto-sync après une erreur
  static const int RETRY_DELAY_SECONDS = 10;

  // ============= Retry Logic =============
  /// Nombre maximum de tentatives pour une opération
  static const int MAX_RETRY_ATTEMPTS = 3;

  /// Délai de base pour le retry exponentiel (en ms)
  static const int BASE_RETRY_DELAY_MS = 1000;

  /// Facteur multiplicateur pour le retry exponentiel
  static const double RETRY_BACKOFF_FACTOR = 1.5;

  // ============= Queue Management =============
  /// Nombre maximum d'opérations en attente avant d'alerte
  static const int MAX_PENDING_OPERATIONS_WARNING = 100;

  /// Nombre maximum d'opérations échouées à conserver
  static const int MAX_FAILED_OPERATIONS_HISTORY = 50;

  /// Clé d'opération haute priorité
  static const int PRIORITY_HIGH = 1;

  /// Clé d'opération priorité normale
  static const int PRIORITY_NORMAL = 0;

  /// Clé d'opération basse priorité
  static const int PRIORITY_LOW = -1;

  // ============= Conflict Resolution =============
  /// Stratégie: "last_write_wins" (seule stratégie supportée actuellement)
  static const String CONFLICT_RESOLUTION_STRATEGY = 'last_write_wins';

  /// Tolérance de timestamp en millisecondes (pour différences légères d'horloge)
  static const int TIMESTAMP_TOLERANCE_MS = 1000;

  // ============= Performance Limits =============
  /// Nombre maximum de dettes à synchroniser par batch
  static const int BATCH_SIZE_DEBTS = 50;

  /// Nombre maximum de paiements à synchroniser par batch
  static const int BATCH_SIZE_PAYMENTS = 100;

  /// Nombre maximum d'additions à synchroniser par batch
  static const int BATCH_SIZE_ADDITIONS = 100;

  /// Nombre maximum de clients à synchroniser par batch
  static const int BATCH_SIZE_CLIENTS = 50;

  // ============= Cache Settings =============
  /// TTL du cache en secondes (avant re-fetch du serveur)
  /// -1 = pas d'expiration
  static const int CACHE_TTL_SECONDS = -1;

  /// Taille maximale du cache en nombre d'entités
  /// 0 = pas de limite
  static const int MAX_CACHE_SIZE = 0;

  /// Compresser les données en cache (optionnel)
  static const bool COMPRESS_CACHE = false;

  // ============= Connectivity Detection =============
  /// Attendre avant de déclarer "offline" après la perte de signal
  static const int OFFLINE_DETECTION_DELAY_MS = 2000;

  /// Attendre avant de déclarer "online" après le retour du signal
  static const int ONLINE_DETECTION_DELAY_MS = 1000;

  // ============= Logging & Monitoring =============
  /// Activer les logs de debug pour HiveService
  static const bool DEBUG_LOGGING = true;

  /// Activer les logs de sync détaillés
  static const bool VERBOSE_SYNC_LOGGING = false;

  /// Activer la capture des performances
  static const bool PERFORMANCE_TRACKING = true;

  /// Intervalle de rapport de performance en secondes
  static const int PERF_REPORT_INTERVAL_SECONDS = 300; // 5 minutes

  // ============= Security & Validation =============
  /// Valider les schémas des données reçues du serveur
  static const bool VALIDATE_SCHEMA = true;

  /// Chiffrer les données en cache (optionnel)
  static const bool ENCRYPT_CACHE = false;

  /// Vérifier l'intégrité des données (checksums)
  static const bool VERIFY_DATA_INTEGRITY = true;

  // ============= Feature Flags =============
  /// Activer l'offline-first mode
  static const bool OFFLINE_FIRST_MODE = true;

  /// Activer auto-sync
  static const bool AUTO_SYNC_ENABLED = true;

  /// Activer la détection de conflit
  static const bool CONFLICT_DETECTION_ENABLED = true;

  /// Activer le retry automatique des opérations échouées
  static const bool AUTO_RETRY_FAILED_OPS = true;

  /// Activer la synchronisation bidirectionnelle
  static const bool BIDIRECTIONAL_SYNC = true;

  // ============= Network Settings =============
  /// Réessayer uniquement en cas de timeout (pas d'autres erreurs)
  static const bool RETRY_ONLY_ON_TIMEOUT = false;

  /// Accepter les connexions insécurisées (HTTP, non HTTPS)
  /// ⚠️ À définir à false en production
  static const bool ALLOW_INSECURE_CONNECTIONS = true;

  // ============= Data Retention =============
  /// Garder l'historique des opérations échouées (en jours)
  static const int FAILED_OPS_RETENTION_DAYS = 7;

  /// Garder les logs de sync (en jours)
  static const int SYNC_LOG_RETENTION_DAYS = 30;

  /// Nettoyer automatiquement les données anciennes
  static const bool AUTO_CLEANUP_ENABLED = true;

  /// Intervalle de nettoyage en secondes
  static const int CLEANUP_INTERVAL_SECONDS = 86400; // 24 heures

  // ============= Optimisation =============
  /// Combiner plusieurs opérations en une seule requête si possible
  static const bool BATCH_OPERATIONS = true;

  /// Utiliser la compression pour les requêtes réseau
  static const bool COMPRESS_NETWORK_DATA = false;

  /// Utiliser le cache pour les GET si récent
  static const bool USE_CACHE_FOR_GET = true;

  // ============= API URLs =============
  /// Base URL de l'API backend
  /// À définir dynamiquement selon l'environnement
  static String API_BASE_URL = 'http://localhost:3000';

  /// Endpoints de l'API
  static const String ENDPOINT_DEBTS = '/debts';
  static const String ENDPOINT_CLIENTS = '/clients';
  static const String ENDPOINT_PAYMENTS = '/payments';
  static const String ENDPOINT_ADDITIONS = '/debt-additions';
  static const String ENDPOINT_SYNC = '/sync';

  // ============= Méthodes Helpers =============

  /// Calculer le délai de retry exponentiel
  static int calculateRetryDelay(int attemptNumber) {
    if (attemptNumber <= 0) return BASE_RETRY_DELAY_MS;
    
    final delay = (BASE_RETRY_DELAY_MS * 
        pow(RETRY_BACKOFF_FACTOR, attemptNumber - 1).toDouble()).toInt();
    
    // Cap à 5 minutes maximum
    return delay > 300000 ? 300000 : delay;
  }

  /// Vérifier si on doit réessayer après X tentatives
  static bool shouldRetry(int attemptNumber) {
    return attemptNumber < MAX_RETRY_ATTEMPTS;
  }

  /// Obtenir la configuration pour un type d'entité
  static int getBatchSize(String entityType) {
    switch (entityType) {
      case 'debts':
        return BATCH_SIZE_DEBTS;
      case 'payments':
        return BATCH_SIZE_PAYMENTS;
      case 'additions':
        return BATCH_SIZE_ADDITIONS;
      case 'clients':
        return BATCH_SIZE_CLIENTS;
      default:
        return 50;
    }
  }

  /// Construire l'URL complète pour un endpoint
  static String buildUrl(String endpoint) {
    return API_BASE_URL + endpoint;
  }

  /// Obtenir les paramètres de timeout
  static Duration getSyncTimeout() {
    return const Duration(seconds: SYNC_REQUEST_TIMEOUT_SECONDS);
  }

  /// Obtenir l'intervalle d'auto-sync
  static Duration getAutoSyncInterval() {
    return const Duration(seconds: AUTO_SYNC_INTERVAL_SECONDS);
  }

  /// Convertir le timeout en millisecondes
  static int getSyncTimeoutMs() {
    return SYNC_REQUEST_TIMEOUT_SECONDS * 1000;
  }

  // ============= Configuration Profiles =============

  /// Configuration pour développement (plus de logs, timeout long)
  static void setupDevelopment() {
    API_BASE_URL = 'http://localhost:3000';
    // Les valeurs par défaut sont déjà appropriées pour le développement
  }

  /// Configuration pour staging (équilibre entre perf et logs)
  static void setupStaging() {
    API_BASE_URL = 'https://staging-api.boutique.local';
  }

  /// Configuration pour production (moins de logs, optimisé)
  static void setupProduction() {
    API_BASE_URL = 'https://api.boutique.app';
  }

  /// Configuration personnalisée
  static void setupCustom({
    required String apiUrl,
    required int autoSyncIntervalSeconds,
    required int maxRetryAttempts,
    required bool debugLogging,
  }) {
    API_BASE_URL = apiUrl;
  }
}

/// Classe pour les constantes de statut de synchronisation
class SyncStatus {
  static const String IDLE = 'idle';
  static const String SYNCING = 'syncing';
  static const String SUCCESS = 'success';
  static const String ERROR = 'error';
  static const String CONFLICT = 'conflict';
  static const String OFFLINE = 'offline';
  static const String QUEUED = 'queued';
}

/// Classe pour les constantes de priorité d'opération
class OperationPriority {
  static const int HIGH = 1;
  static const int NORMAL = 0;
  static const int LOW = -1;
}

/// Classe pour les types d'entité
class EntityType {
  static const String CLIENT = 'client';
  static const String DEBT = 'debt';
  static const String PAYMENT = 'payment';
  static const String DEBT_ADDITION = 'debt_addition';
}

/// Classe pour les opérations de sync
class SyncOperation {
  static const String CREATE = 'CREATE';
  static const String UPDATE = 'UPDATE';
  static const String DELETE = 'DELETE';
  static const String SYNC = 'SYNC';
}
