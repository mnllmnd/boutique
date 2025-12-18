import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';

class ApiConfig {
  static String getBaseUrl() {
    // ✅ On web, skip dotenv (no .env file available)
    if (kIsWeb) {
      return 'https://vocal-fernandina-llmndg-0b759290.koyeb.app/api';
    }
    // On mobile, try to get from .env, fallback to hardcoded
    return dotenv.env['API_BASE_URL'] ?? 'https://vocal-fernandina-llmndg-0b759290.koyeb.app/api';
  }
}
