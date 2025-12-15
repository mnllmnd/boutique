/// Configuration optimisée pour Flutter Web (évite les écrans blancs)
/// 
/// Cette configuration s'applique automatiquement au démarrage de l'app.
/// Les optimisations incluent:
/// - Renderer HTML pour plus de stabilité sur iOS/Web
/// - Timeouts augmentés pour les requêtes réseau
/// - Caching local automatique
/// - Gestion d'erreurs robuste
/// - Animations simplifiées

class FlutterWebConfig {
  /// Timeout par défaut pour les requêtes réseau (secondes)
  /// Augmenté de 8s à 12s pour éviter les timeouts sur connections lentes
  static const int defaultNetworkTimeoutSeconds = 12;

  /// Intervalle d'auto-refresh en arrière-plan (secondes)
  /// Réduit pour maintenir les données à jour sans bloquer l'UI
  static const int autoRefreshIntervalSeconds = 5;

  /// Délai de debounce pour la recherche (millisecondes)
  /// Évite les requêtes excessives lors de la saisie
  static const int searchDebounceMs = 400;

  /// Taille max du cache local (MB)
  /// Limité pour éviter les problèmes de mémoire sur mobile
  static const int maxLocalCacheMb = 50;

  /// Activer le mode debug avec logs verbeux
  static const bool debugLogsEnabled = true;

  /// Messages d'erreur user-friendly
  static const Map<String, String> errorMessages = {
    'timeout': 'La connexion a pris trop de temps. Les données locales sont affichées.',
    'network': 'Erreur réseau. Les données locales sont affichées.',
    'parse': 'Erreur lors du traitement des données.',
    'unknown': 'Une erreur est survenue. Veuillez réessayer.',
  };

  /// Éviter les animations trop complexes sur Web
  static const Map<String, int> animationDurationsMs = {
    'fast': 0,      // Pas d'animation sur Web (plus stable)
    'normal': 0,    // Pas d'animation sur Web (plus stable)
    'slow': 0,      // Pas d'animation sur Web (plus stable)
  };

  /// Configuration du renderer Flutter
  static const Map<String, dynamic> rendererConfig = {
    'renderer': 'html',  // Forcer HTML renderer (plus léger que CanvasKit)
    'canvasKitMaximumSize': 0,  // Désactiver CanvasKit
  };

  static void logIfDebugEnabled(String message) {
    if (debugLogsEnabled) {
      print('🐛 [FlutterWeb] $message');
    }
  }

  static String getErrorMessage(String errorType) {
    return errorMessages[errorType] ?? errorMessages['unknown']!;
  }
}
