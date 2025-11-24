import 'package:shared_preferences/shared_preferences.dart';

/// Configuration du mode développement
class DevConfig {
  static final DevConfig _instance = DevConfig._internal();
  factory DevConfig() => _instance;
  DevConfig._internal();

  // Configuration
  static const bool AUTO_LOGIN_ENABLED = true;
  static const bool VERBOSE_LOGGING = true;
  static const String DEV_ACCOUNT_PHONE = '784666912';
  static const String DEV_ACCOUNT_PIN = '1234';

  /// Active/désactive le mode développement
  static Future<void> setDevMode(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dev_config_mode', enabled);
    _logDevConfig('Dev Mode', enabled);
  }

  /// Retourne l'état du mode développement
  static Future<bool> isDevModeEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('dev_config_mode') ?? AUTO_LOGIN_ENABLED;
  }

  /// Active/désactive les logs verbeux
  static Future<void> setVerboseLogging(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dev_config_verbose', enabled);
    _logDevConfig('Verbose Logging', enabled);
  }

  /// Retourne l'état du logging verbeux
  static Future<bool> isVerboseLoggingEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('dev_config_verbose') ?? VERBOSE_LOGGING;
  }

  /// Récupère les stats de développement
  static Future<Map<String, dynamic>> getStats() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'dev_mode_enabled': await isDevModeEnabled(),
      'verbose_logging': await isVerboseLoggingEnabled(),
      'auto_login_enabled': AUTO_LOGIN_ENABLED,
      'dev_account': DEV_ACCOUNT_PHONE,
    };
  }

  /// Réinitialise toute la config dev
  static Future<void> resetDevConfig() async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.remove('dev_config_mode'),
      prefs.remove('dev_config_verbose'),
    ]);
    print('🔄 [DevConfig] Configuration réinitialisée');
  }

  /// Log helper
  static void _logDevConfig(String key, bool value) {
    print('⚙️  [DevConfig] $key = ${value ? '✅ ON' : '❌ OFF'}');
  }
}

/// Helper pour logger les évènements dev
class DevLog {
  static Future<bool> shouldLog() async {
    return DevConfig.isVerboseLoggingEnabled();
  }

  static Future<void> info(String message) async {
    if (await shouldLog()) {
      print('ℹ️  [Dev] $message');
    }
  }

  static Future<void> success(String message) async {
    if (await shouldLog()) {
      print('✅ [Dev] $message');
    }
  }

  static Future<void> warning(String message) async {
    if (await shouldLog()) {
      print('⚠️  [Dev] $message');
    }
  }

  static Future<void> error(String message) async {
    if (await shouldLog()) {
      print('❌ [Dev] $message');
    }
  }
}
