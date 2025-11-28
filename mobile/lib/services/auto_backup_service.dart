// Automatic backup service for Hive data
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class AutoBackupService {
  static const String _lastBackupKey = 'last_backup_timestamp';
  static const Duration _backupInterval = Duration(hours: 24);

  /// Perform automatic backup if needed
  static Future<bool> performAutomaticBackup({
    required String backupData,
    required String apiHost,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final lastBackup = prefs.getInt(_lastBackupKey);
    final now = DateTime.now().millisecondsSinceEpoch;

    // Check if backup is needed
    if (lastBackup != null) {
      final duration = Duration(milliseconds: now - lastBackup);
      if (duration < _backupInterval) {
        return false; // Too soon to backup
      }
    }

    try {
      await _uploadBackup(backupData, apiHost);
      await prefs.setInt(_lastBackupKey, now);
      print('✅ Automatic backup completed');
      return true;
    } catch (e) {
      print('⚠️ Backup failed (offline mode): $e');
      // Don't throw - app continues with local-only backup
      return false;
    }
  }

  /// Upload backup to server
  static Future<void> _uploadBackup(String data, String apiHost) async {
    final url = Uri.parse('$apiHost/backup/upload');
    final timestamp = DateTime.now().toIso8601String();

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'data': data,
        'timestamp': timestamp,
        'platform': 'mobile',
      }),
    ).timeout(
      const Duration(seconds: 30),
      onTimeout: () => throw TimeoutException('Backup upload timeout'),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Backup upload failed: ${response.statusCode}');
    }
  }

  /// Get local backup timestamp
  static Future<DateTime?> getLastBackupTime() async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getInt(_lastBackupKey);
    if (timestamp == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(timestamp);
  }
}

class TimeoutException implements Exception {
  final String message;
  TimeoutException(this.message);
  @override
  String toString() => message;
}
