import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

class GuestService {
  static String _baseUrl = 'http://localhost:3000/api';

  // Initialize with correct base URL (call this from main.dart)
  static void initWithBaseUrl(String baseUrl) {
    _baseUrl = baseUrl;
    print('🔧 [GuestService] Initialized with baseUrl: $_baseUrl');
  }

  static String get baseUrl {
    // If not manually set, compute it
    if (_baseUrl == 'http://localhost:3000/api') {
      if (kIsWeb) return 'http://localhost:3000/api';
      try {
        if (Platform.isAndroid) return 'http://10.0.2.2:3000/api';
      } catch (_) {}
      return 'http://localhost:3000/api';
    }
    return _baseUrl;
  }

  static Future<Map<String, dynamic>?> createGuestAccount() async {
    try {
      final url = '$baseUrl/auth/create-guest';
      print('\n🔧 ═══════════════════════════════════════');
      print('🔧 [GuestService.createGuestAccount] Starting');
      print('🔧 [GuestService.createGuestAccount] URL: $url');
      print('🔧 [GuestService.createGuestAccount] Headers: Content-Type: application/json');
      print('🔧 ═══════════════════════════════════════');
      
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 8));
      
      print('✅ [GuestService.createGuestAccount] Response received');
      print('✅ [GuestService.createGuestAccount] Status Code: ${response.statusCode}');
      print('✅ [GuestService.createGuestAccount] Status Code Type: ${response.statusCode.runtimeType}');
      print('✅ [GuestService.createGuestAccount] Response Body: ${response.body}');
      print('✅ [GuestService.createGuestAccount] Response Headers: ${response.headers}');
      
      // Check all possible success codes
      if (response.statusCode == 201) {
        print('✅ [GuestService.createGuestAccount] Status 201 - Parsing response...');
        final data = json.decode(response.body);
        print('✅ [GuestService.createGuestAccount] Decoded JSON: $data');
        
        if (data['guest'] != null) {
          print('✅ [GuestService.createGuestAccount] Guest object found: ${data['guest']['phone']}');
          return data['guest'];
        } else {
          print('❌ [GuestService.createGuestAccount] No guest field in response!');
          print('❌ [GuestService.createGuestAccount] Response keys: ${data.keys.toList()}');
        }
      } else if (response.statusCode >= 200 && response.statusCode < 300) {
        print('⚠️  [GuestService.createGuestAccount] Status ${response.statusCode} (not 201)');
        print('⚠️  [GuestService.createGuestAccount] Trying to parse anyway...');
        try {
          final data = json.decode(response.body);
          if (data['guest'] != null) {
            print('✅ [GuestService.createGuestAccount] Found guest in 2xx response');
            return data['guest'];
          }
        } catch (e) {
          print('❌ [GuestService.createGuestAccount] Could not parse body: $e');
        }
      } else {
        print('❌ [GuestService.createGuestAccount] Status ${response.statusCode} (error)');
        try {
          final error = json.decode(response.body);
          print('❌ [GuestService.createGuestAccount] Error response: $error');
        } catch (_) {
          print('❌ [GuestService.createGuestAccount] Could not parse error body');
        }
      }
      print('❌ [GuestService.createGuestAccount] Returning null');
      print('🔧 ═══════════════════════════════════════\n');
      return null;
    } catch (e) {
      print('\n❌ ═══════════════════════════════════════');
      print('❌ [GuestService.createGuestAccount] EXCEPTION');
      print('❌ Error type: ${e.runtimeType}');
      print('❌ Error message: $e');
      print('❌ ═══════════════════════════════════════\n');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> convertGuestToUser({
    required String guestPhone,
    required String newPhone,
    String? pin,
    String? firstName,
    String? lastName,
    String? shopName,
  }) async {
    try {
      final url = '$baseUrl/auth/register-convert-guest';
      print('🔧 [GuestService.convertGuestToUser] Calling: $url');
      
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'guest_phone': guestPhone,
          'phone': newPhone,
          'pin': pin,
          'first_name': firstName,
          'last_name': lastName,
          'shop_name': shopName,
        }),
      ).timeout(const Duration(seconds: 8));
      
      print('✅ [GuestService.convertGuestToUser] Response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('✅ [GuestService.convertGuestToUser] Conversion successful: ${data['owner']['phone']}');
        return data;
      } else {
        final error = json.decode(response.body);
        print('❌ [GuestService.convertGuestToUser] Error: ${error['error']}');
        throw Exception(error['error']);
      }
    } catch (e) {
      print('❌ [GuestService.convertGuestToUser] Error: $e');
      rethrow;
    }
  }

  static bool isGuestUser(String? phone) {
    return phone != null && phone.startsWith('guest_');
  }
}