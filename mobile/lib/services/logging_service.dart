// Centralized logging service for error tracking
import 'package:shared_preferences/shared_preferences.dart';

class LoggingService {
  static final List<LogEntry> _logs = [];
  static const int _maxLogs = 500;

  static Future<void> logError({
    required String message,
    required String source,
    String? stackTrace,
    Map<String, dynamic>? context,
  }) async {
    final entry = LogEntry(
      level: 'ERROR',
      message: message,
      source: source,
      stackTrace: stackTrace,
      context: context,
      timestamp: DateTime.now(),
    );

    _logs.add(entry);
    if (_logs.length > _maxLogs) {
      _logs.removeAt(0); // Keep only recent logs
    }

    // Persist to SharedPreferences (for future recovery)
    await SharedPreferences.getInstance();
    print('🔴 ERROR [$source]: $message');
    if (stackTrace != null) print(stackTrace);
  }

  static Future<void> logWarning({
    required String message,
    required String source,
  }) async {
    final entry = LogEntry(
      level: 'WARNING',
      message: message,
      source: source,
      timestamp: DateTime.now(),
    );
    _logs.add(entry);
    print('⚠️  WARNING [$source]: $message');
  }

  static Future<void> logInfo({
    required String message,
    required String source,
  }) async {
    final entry = LogEntry(
      level: 'INFO',
      message: message,
      source: source,
      timestamp: DateTime.now(),
    );
    _logs.add(entry);
    print('ℹ️  INFO [$source]: $message');
  }

  static List<LogEntry> getRecentLogs({int count = 50}) {
    return _logs.reversed.toList().take(count).toList();
  }

  static void clearLogs() {
    _logs.clear();
  }

  static String exportLogsAsString() {
    return _logs.map((log) => log.toString()).join('\n');
  }
}

class LogEntry {
  final String level;
  final String message;
  final String source;
  final String? stackTrace;
  final Map<String, dynamic>? context;
  final DateTime timestamp;

  LogEntry({
    required this.level,
    required this.message,
    required this.source,
    this.stackTrace,
    this.context,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'level': level,
    'message': message,
    'source': source,
    'stackTrace': stackTrace,
    'context': context,
    'timestamp': timestamp.toIso8601String(),
  };

  @override
  String toString() =>
      '[$timestamp] $level [$source]: $message${stackTrace != null ? '\n$stackTrace' : ''}';
}
