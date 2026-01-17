import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';

/// Network error types for better error handling
enum NetworkErrorType {
  noConnection,
  timeout,
  serverError,
  unknown,
}

/// Result class for network error checking
class NetworkErrorResult {
  final bool isNetworkError;
  final NetworkErrorType type;
  final String userMessage;

  const NetworkErrorResult({
    required this.isNetworkError,
    required this.type,
    required this.userMessage,
  });

  static const connected = NetworkErrorResult(
    isNetworkError: false,
    type: NetworkErrorType.unknown,
    userMessage: '',
  );
}

/// Utility class for network error handling
class NetworkUtils {
  /// Check if an error is network-related and return appropriate user message
  static NetworkErrorResult analyzeError(dynamic error) {
    final errorString = error.toString().toLowerCase();

    // Socket/Connection errors
    if (error is SocketException ||
        errorString.contains('socketexception') ||
        errorString.contains('connection refused') ||
        errorString.contains('network is unreachable') ||
        errorString.contains('no address associated') ||
        errorString.contains('failed host lookup') ||
        errorString.contains('connection reset') ||
        errorString.contains('connection closed')) {
      debugPrint('NetworkUtils: Detected SocketException');
      return const NetworkErrorResult(
        isNetworkError: true,
        type: NetworkErrorType.noConnection,
        userMessage: 'İnternet bağlantınızı kontrol edin',
      );
    }

    // Timeout errors
    if (error is TimeoutException ||
        errorString.contains('timeout') ||
        errorString.contains('timed out') ||
        errorString.contains('deadline exceeded')) {
      debugPrint('NetworkUtils: Detected TimeoutException');
      return const NetworkErrorResult(
        isNetworkError: true,
        type: NetworkErrorType.timeout,
        userMessage: 'Bağlantı zaman aşımına uğradı. Tekrar deneyin.',
      );
    }

    // Firebase/Server errors that might be network-related
    if (errorString.contains('unavailable') ||
        errorString.contains('network_error') ||
        errorString.contains('network-request-failed') ||
        errorString.contains('a]')) {
      debugPrint('NetworkUtils: Detected Firebase network error');
      return const NetworkErrorResult(
        isNetworkError: true,
        type: NetworkErrorType.serverError,
        userMessage: 'Sunucuya bağlanılamadı. İnternet bağlantınızı kontrol edin.',
      );
    }

    // Not a network error
    return NetworkErrorResult.connected;
  }

  /// Check if error is network-related (simple boolean check)
  static bool isNetworkError(dynamic error) {
    return analyzeError(error).isNetworkError;
  }

  /// Get user-friendly message for an error
  static String getUserMessage(dynamic error, {String? fallbackMessage}) {
    final result = analyzeError(error);
    if (result.isNetworkError) {
      return result.userMessage;
    }
    return fallbackMessage ?? 'Bir hata oluştu';
  }

  /// Wrap an async operation with network error handling
  static Future<T?> withNetworkHandling<T>({
    required Future<T> Function() operation,
    required void Function(String message) onError,
    String? fallbackMessage,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    try {
      return await operation().timeout(timeout);
    } on TimeoutException {
      onError('Bağlantı zaman aşımına uğradı');
      return null;
    } on SocketException {
      onError('İnternet bağlantınızı kontrol edin');
      return null;
    } catch (e) {
      final result = analyzeError(e);
      if (result.isNetworkError) {
        onError(result.userMessage);
      } else {
        onError(fallbackMessage ?? 'Bir hata oluştu');
      }
      debugPrint('NetworkUtils: Operation failed: $e');
      return null;
    }
  }
}
