import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import '../config/dev_config.dart';

/// Service pour l'auto-login en mode développement
/// Garantit que le compte test existe et l'auto-login est toujours disponible
class DevAutoLoginService {
  static final DevAutoLoginService _instance = DevAutoLoginService._internal();
  factory DevAutoLoginService() => _instance;
  DevAutoLoginService._internal();

  // Dev constants
  static const String DEV_PHONE = '784666912';
  static const String DEV_PIN = '1234';
  static const String DEV_FIRST_NAME = 'Dev';
  static const String DEV_LAST_NAME = 'Test';
  static const String DEV_SHOP_NAME = 'Test Shop';

  String get apiHost {
    if (kIsWeb) return 'http://localhost:3000/api';
    try {
      if (Platform.isAndroid) return 'http://10.0.2.2:3000/api';
    } catch (_) {}
    return 'http://localhost:3000/api';
  }

  /// Vérifie si le mode dev est activé
  /// En dev, lire depuis une variable d'environnement ou un fichier config
  Future<bool> isDevModeEnabled() async {
    try {
      return await DevConfig.isDevModeEnabled();
    } catch (_) {
      return kIsWeb; // Fallback : activer sur web
    }
  }

  /// Tente un auto-login en mode dev
  /// Retourne null si pas en mode dev ou si le login échoue
  Future<Map<String, dynamic>?> tryAutoLoginDev() async {
    if (!await isDevModeEnabled()) {
      return null;
    }

    try {
      print('🔧 [Dev Mode] Attempting auto-login for $DEV_PHONE');

      // Récupérer les credentials en cache
      final prefs = await SharedPreferences.getInstance();
      final cachedPhone = prefs.getString('pin_auth_offline_phone');
      final cachedToken = prefs.getString('pin_auth_offline_token');
      final cachedId = prefs.getInt('pin_auth_offline_user_id');

      if (cachedPhone != null && cachedToken != null && cachedId != null) {
        print('🔑 [Dev Mode] Using cached credentials for $cachedPhone');

        // Vérifier le token (optionnel en dev)
        try {
          final verifyRes = await http.post(
            Uri.parse('$apiHost/auth/verify-token'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'auth_token': cachedToken}),
          ).timeout(const Duration(seconds: 5));

          if (verifyRes.statusCode == 200) {
            final data = jsonDecode(verifyRes.body);
            print('✅ [Dev Mode] Token verified for ${data['phone']}');

            return {
              'phone': data['phone'] ?? cachedPhone,
              'shop_name': data['shop_name'] ?? prefs.getString('pin_auth_offline_shop_name'),
              'id': data['id'] ?? cachedId,
              'first_name': data['first_name'] ?? prefs.getString('pin_auth_offline_first_name'),
              'last_name': data['last_name'] ?? prefs.getString('pin_auth_offline_last_name'),
              'auth_token': cachedToken,
              'auto_login': true,
            };
          }
        } catch (e) {
          print('⚠️  [Dev Mode] Token verification failed: $e');
          // Continue avec les données en cache même si la vérification échoue en dev
          return {
            'phone': cachedPhone,
            'shop_name': prefs.getString('pin_auth_offline_shop_name'),
            'id': cachedId,
            'first_name': prefs.getString('pin_auth_offline_first_name'),
            'last_name': prefs.getString('pin_auth_offline_last_name'),
            'auth_token': cachedToken,
            'auto_login': true,
            'offline': true,
          };
        }
      }

      // Si pas de cache, tenter de créer le compte test et le seeder
      print('📝 [Dev Mode] No cached credentials. Attempting to seed dev account...');
      final seedResult = await _seedDevAccount();

      if (seedResult != null) {
        print('✅ [Dev Mode] Dev account seeded successfully');
        return seedResult;
      }

      return null;
    } catch (e) {
      print('❌ [Dev Mode] Auto-login error: $e');
      return null;
    }
  }

  /// Seed du compte de développement
  Future<Map<String, dynamic>?> _seedDevAccount() async {
    try {
      // Appel au seed du backend
      final seedRes = await http.post(
        Uri.parse('$apiHost/auth/seed-dev-account'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phone': DEV_PHONE,
          'pin': DEV_PIN,
          'first_name': DEV_FIRST_NAME,
          'last_name': DEV_LAST_NAME,
          'shop_name': DEV_SHOP_NAME,
        }),
      ).timeout(const Duration(seconds: 10));

      if (seedRes.statusCode == 200 || seedRes.statusCode == 201) {
        final data = jsonDecode(seedRes.body);
        print('✅ [Dev Mode] Dev account seeded: ${data['message'] ?? 'OK'}');

        // Mettre en cache les credentials
        await _cacheDevCredentials(data);

        return {
          'phone': data['phone'] ?? DEV_PHONE,
          'shop_name': data['shop_name'] ?? DEV_SHOP_NAME,
          'id': data['id'] ?? 1,
          'first_name': data['first_name'] ?? DEV_FIRST_NAME,
          'last_name': data['last_name'] ?? DEV_LAST_NAME,
          'auth_token': data['auth_token'],
          'auto_login': true,
          'seeded': true,
        };
      } else {
        print('⚠️  [Dev Mode] Seed failed with status ${seedRes.statusCode}');
        print('Response: ${seedRes.body}');
        return null;
      }
    } catch (e) {
      print('❌ [Dev Mode] Seed error: $e');
      return null;
    }
  }

  /// Met en cache les credentials du compte dev
  Future<void> _cacheDevCredentials(Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await Future.wait([
        prefs.setString('pin_auth_offline_phone', data['phone'] ?? DEV_PHONE),
        prefs.setString('pin_auth_offline_token', data['auth_token'] ?? ''),
        prefs.setString('pin_auth_offline_shop_name', data['shop_name'] ?? DEV_SHOP_NAME),
        prefs.setString('pin_auth_offline_first_name', data['first_name'] ?? DEV_FIRST_NAME),
        prefs.setString('pin_auth_offline_last_name', data['last_name'] ?? DEV_LAST_NAME),
        prefs.setInt('pin_auth_offline_user_id', data['id'] ?? 1),
        prefs.setInt(
          'pin_auth_offline_token_expiry',
          DateTime.now().add(const Duration(days: 30)).millisecondsSinceEpoch,
        ),
      ]);
      print('✅ [Dev Mode] Dev credentials cached');
    } catch (e) {
      print('❌ [Dev Mode] Error caching credentials: $e');
    }
  }

  /// Bascule le mode dev
  Future<void> setDevModeEnabled(bool enabled) async {
    try {
      await DevConfig.setDevMode(enabled);
    } catch (e) {
      print('❌ Error setting dev mode: $e');
    }
  }

  /// Efface les credentials dev
  Future<void> clearDevCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await Future.wait([
        prefs.remove('pin_auth_offline_phone'),
        prefs.remove('pin_auth_offline_token'),
        prefs.remove('pin_auth_offline_shop_name'),
        prefs.remove('pin_auth_offline_first_name'),
        prefs.remove('pin_auth_offline_last_name'),
        prefs.remove('pin_auth_offline_user_id'),
        prefs.remove('pin_auth_offline_token_expiry'),
      ]);
      print('✅ [Dev Mode] Dev credentials cleared');
    } catch (e) {
      print('❌ Error clearing dev credentials: $e');
    }
  }
}
