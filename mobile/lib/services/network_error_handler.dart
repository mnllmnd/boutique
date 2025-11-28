// Network error handling and recovery service
import 'package:http/http.dart' as http;
import 'dart:convert';

class NetworkErrorHandler {
  /// Handle network errors with retry logic
  static Future<T?> withRetry<T>(
    Future<T> Function() request, {
    int maxRetries = 3,
    Duration delay = const Duration(seconds: 2),
  }) async {
    int retryCount = 0;
    
    while (retryCount < maxRetries) {
      try {
        return await request();
      } on http.ClientException catch (e) {
        retryCount++;
        if (retryCount >= maxRetries) {
          print('❌ Network request failed after $maxRetries retries: $e');
          rethrow;
        }
        print('⚠️ Request failed (attempt $retryCount/$maxRetries), retrying in ${delay.inSeconds}s...');
        await Future.delayed(delay);
      } catch (e) {
        print('❌ Unexpected error: $e');
        rethrow;
      }
    }
    return null;
  }

  /// Wrap HTTP response with error handling
  static Map<String, dynamic> handleResponse(http.Response response) {
    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else if (response.statusCode == 401) {
      throw UnauthorizedException('Unauthorized - Please login again');
    } else if (response.statusCode == 404) {
      throw NotFoundException('Resource not found');
    } else if (response.statusCode >= 500) {
      throw ServerException('Server error (${response.statusCode})');
    } else {
      throw HttpException('HTTP Error ${response.statusCode}: ${response.body}');
    }
  }
}

class UnauthorizedException implements Exception {
  final String message;
  UnauthorizedException(this.message);
  @override
  String toString() => message;
}

class NotFoundException implements Exception {
  final String message;
  NotFoundException(this.message);
  @override
  String toString() => message;
}

class ServerException implements Exception {
  final String message;
  ServerException(this.message);
  @override
  String toString() => message;
}

class HttpException implements Exception {
  final String message;
  HttpException(this.message);
  @override
  String toString() => message;
}
