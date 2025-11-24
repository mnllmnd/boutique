import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Service pour gérer l'authentification offline
/// Cache les identifiants et permet login sans serveur
class AuthOfflineService {
  static final AuthOfflineService _instance = AuthOfflineService._internal();
  factory AuthOfflineService() => _instance;
  AuthOfflineService._internal();

  // Keys pour SharedPreferences
  static const String _KEY_PREFIX = 'auth_offline_';
  static const String _KEY_PHONE = '${_KEY_PREFIX}phone';
  static const String _KEY_PASSWORD_HASH = '${_KEY_PREFIX}password_hash';
  static const String _KEY_TOKEN = '${_KEY_PREFIX}token';
  static const String _KEY_TOKEN_EXPIRY = '${_KEY_PREFIX}token_expiry';
  static const String _KEY_FIRST_NAME = '${_KEY_PREFIX}first_name';
  static const String _KEY_LAST_NAME = '${_KEY_PREFIX}last_name';
  static const String _KEY_SHOP_NAME = '${_KEY_PREFIX}shop_name';
  static const String _KEY_USER_ID = '${_KEY_PREFIX}user_id';
  static const String _KEY_LAST_LOGIN = '${_KEY_PREFIX}last_login';

  /// Sauvegarde les credentials après une connexion réussie
  /// Appelé après authentification serveur avec succès
  Future<void> cacheCredentials({
    required String phone,
    required String password, // Password en clair - sera hashé
    required String token,
    required String firstName,
    required String lastName,
    required String shopName,
    required int userId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final passwordHash = _hashPassword(password);
      final now = DateTime.now();

      await Future.wait([
        prefs.setString(_KEY_PHONE, phone),
        prefs.setString(_KEY_PASSWORD_HASH, passwordHash),
        prefs.setString(_KEY_TOKEN, token),
        prefs.setInt(_KEY_TOKEN_EXPIRY, now.add(const Duration(days: 30)).millisecondsSinceEpoch),
        prefs.setString(_KEY_FIRST_NAME, firstName),
        prefs.setString(_KEY_LAST_NAME, lastName),
        prefs.setString(_KEY_SHOP_NAME, shopName),
        prefs.setInt(_KEY_USER_ID, userId),
        prefs.setInt(_KEY_LAST_LOGIN, now.millisecondsSinceEpoch),
      ]);

      print('✅ Credentials cached for $phone');
    } catch (e) {
      print('❌ Error caching credentials: $e');
      rethrow;
    }
  }

  /// Tente une authentification offline
  /// Retourne true si les identifiants correspondent au cache
  Future<bool> authenticateOffline({
    required String phone,
    required String password,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedPhone = prefs.getString(_KEY_PHONE);
      final cachedPasswordHash = prefs.getString(_KEY_PASSWORD_HASH);
      final tokenExpiry = prefs.getInt(_KEY_TOKEN_EXPIRY);

      // Vérifier que des credentials sont en cache
      if (cachedPhone == null || cachedPasswordHash == null) {
        print('⚠️  No cached credentials found');
        return false;
      }

      // Vérifier que le phone correspond
      if (cachedPhone != phone) {
        print('⚠️  Phone mismatch: $phone != $cachedPhone');
        return false;
      }

      // Vérifier que le token n'a pas expiré
      if (tokenExpiry != null && DateTime.now().millisecondsSinceEpoch > tokenExpiry) {
        print('⚠️  Cached token expired');
        await clearCachedCredentials();
        return false;
      }

      // Vérifier le mot de passe
      final passwordHash = _hashPassword(password);
      if (passwordHash != cachedPasswordHash) {
        print('⚠️  Password mismatch');
        return false;
      }

      print('✅ Offline authentication successful for $phone');
      return true;
    } catch (e) {
      print('❌ Error during offline authentication: $e');
      return false;
    }
  }

  /// Récupère les données utilisateur en cache
  Future<Map<String, dynamic>?> getCachedUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final phone = prefs.getString(_KEY_PHONE);
      final token = prefs.getString(_KEY_TOKEN);

      if (phone == null || token == null) {
        return null;
      }

      return {
        'phone': phone,
        'token': token,
        'firstName': prefs.getString(_KEY_FIRST_NAME),
        'lastName': prefs.getString(_KEY_LAST_NAME),
        'shopName': prefs.getString(_KEY_SHOP_NAME),
        'userId': prefs.getInt(_KEY_USER_ID),
        'lastLogin': DateTime.fromMillisecondsSinceEpoch(
          prefs.getInt(_KEY_LAST_LOGIN) ?? 0,
        ),
      };
    } catch (e) {
      print('❌ Error retrieving cached user data: $e');
      return null;
    }
  }

  /// Récupère juste le token en cache
  Future<String?> getCachedToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_KEY_TOKEN);
    } catch (e) {
      print('❌ Error retrieving cached token: $e');
      return null;
    }
  }

  /// Vérifie si des credentials sont en cache et valides
  Future<bool> hasValidCachedCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedPhone = prefs.getString(_KEY_PHONE);
      final cachedToken = prefs.getString(_KEY_TOKEN);
      final tokenExpiry = prefs.getInt(_KEY_TOKEN_EXPIRY);

      if (cachedPhone == null || cachedToken == null) {
        return false;
      }

      // Vérifier l'expiration du token
      if (tokenExpiry != null && DateTime.now().millisecondsSinceEpoch > tokenExpiry) {
        print('⚠️  Cached token expired, clearing cache');
        await clearCachedCredentials();
        return false;
      }

      return true;
    } catch (e) {
      print('❌ Error checking cached credentials: $e');
      return false;
    }
  }

  /// Récupère le phone du dernier login réussi
  Future<String?> getLastLoginPhone() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_KEY_PHONE);
    } catch (e) {
      print('❌ Error getting last login phone: $e');
      return null;
    }
  }

  /// Met à jour le token (par exemple après une sync réussie)
  Future<void> updateCachedToken(String newToken) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();

      await Future.wait([
        prefs.setString(_KEY_TOKEN, newToken),
        prefs.setInt(_KEY_TOKEN_EXPIRY, now.add(const Duration(days: 30)).millisecondsSinceEpoch),
      ]);

      print('✅ Cached token updated');
    } catch (e) {
      print('❌ Error updating cached token: $e');
      rethrow;
    }
  }

  /// Efface tous les credentials en cache
  Future<void> clearCachedCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await Future.wait([
        prefs.remove(_KEY_PHONE),
        prefs.remove(_KEY_PASSWORD_HASH),
        prefs.remove(_KEY_TOKEN),
        prefs.remove(_KEY_TOKEN_EXPIRY),
        prefs.remove(_KEY_FIRST_NAME),
        prefs.remove(_KEY_LAST_NAME),
        prefs.remove(_KEY_SHOP_NAME),
        prefs.remove(_KEY_USER_ID),
        prefs.remove(_KEY_LAST_LOGIN),
      ]);

      print('✅ Cached credentials cleared');
    } catch (e) {
      print('❌ Error clearing cached credentials: $e');
      rethrow;
    }
  }

  /// Hash sécurisé du mot de passe
  /// Utilise SHA-256 avec un salt simple
  static String _hashPassword(String password) {
    // Dans une app réelle, utiliser un vrai salt
    const String salt = 'boutique_app_salt_2024';
    return sha256.convert(utf8.encode('$password$salt')).toString();
  }

  /// Retourne l'état de connexion offline
  Future<Map<String, dynamic>> getOfflineAuthStatus() async {
    final hasValid = await hasValidCachedCredentials();
    final userData = await getCachedUserData();
    final lastLogin = userData?['lastLogin'] as DateTime?;

    return {
      'isAuthenticated': hasValid,
      'phone': userData?['phone'],
      'firstName': userData?['firstName'],
      'lastName': userData?['lastName'],
      'shopName': userData?['shopName'],
      'lastLoginAt': lastLogin,
      'canLoginOffline': hasValid,
      'message': hasValid
          ? 'Authenticated offline (last login: ${_formatDate(lastLogin)})'
          : 'Not authenticated offline',
    };
  }

  static String _formatDate(DateTime? date) {
    if (date == null) return 'unknown';
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays < 30) {
      return '${diff.inDays}d ago';
    } else {
      return date.toString().split('.')[0];
    }
  }
}
