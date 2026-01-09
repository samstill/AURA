/// Project Aura - API Exceptions
/// ==============================
/// Typed exception classes for structured API error handling.
/// Enables graceful error recovery and user-friendly messages.
library;

import 'package:dio/dio.dart';

/// Base exception for all API-related errors
sealed class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic originalError;

  const ApiException({
    required this.message,
    this.statusCode,
    this.originalError,
  });

  @override
  String toString() => 'ApiException: $message (status: $statusCode)';

  /// Parse a DioException into the appropriate ApiException type
  static ApiException fromDioException(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return NetworkException(
          message: 'Connection timed out. Please check your internet.',
          originalError: e,
        );
      case DioExceptionType.connectionError:
        return NetworkException(
          message: 'No internet connection.',
          originalError: e,
        );
      case DioExceptionType.badResponse:
        return _parseResponseError(e);
      case DioExceptionType.cancel:
        return NetworkException(
          message: 'Request was cancelled.',
          originalError: e,
        );
      default:
        return UnknownApiException(
          message: e.message ?? 'An unexpected error occurred.',
          originalError: e,
        );
    }
  }

  static ApiException _parseResponseError(DioException e) {
    final statusCode = e.response?.statusCode;
    final data = e.response?.data;

    switch (statusCode) {
      case 401:
        return AuthException(
          message: 'Session expired. Please log in again.',
          statusCode: statusCode,
          originalError: e,
        );
      case 403:
        return AuthException(
          message: 'You don\'t have permission to access this resource.',
          statusCode: statusCode,
          originalError: e,
        );
      case 400:
        return ValidationException(
          message: _extractErrorMessage(data) ?? 'Invalid request.',
          statusCode: statusCode,
          fieldErrors: _extractFieldErrors(data),
          originalError: e,
        );
      case 404:
        return NotFoundException(
          message: 'Resource not found.',
          statusCode: statusCode,
          originalError: e,
        );
      case 422:
        return ValidationException(
          message: _extractErrorMessage(data) ?? 'Validation failed.',
          statusCode: statusCode,
          fieldErrors: _extractFieldErrors(data),
          originalError: e,
        );
      case 429:
        return RateLimitException(
          message: 'Too many requests. Please wait a moment.',
          statusCode: statusCode,
          retryAfterSeconds: _extractRetryAfter(e.response),
          originalError: e,
        );
      case 500:
      case 502:
      case 503:
      case 504:
        return ServerException(
          message: 'Server error. Please try again later.',
          statusCode: statusCode,
          originalError: e,
        );
      default:
        return UnknownApiException(
          message: _extractErrorMessage(data) ?? 'An error occurred.',
          statusCode: statusCode,
          originalError: e,
        );
    }
  }

  static String? _extractErrorMessage(dynamic data) {
    if (data == null) return null;
    if (data is String) return data;
    if (data is Map) {
      return data['detail'] as String? ??
          data['message'] as String? ??
          data['error'] as String?;
    }
    return null;
  }

  static Map<String, List<String>>? _extractFieldErrors(dynamic data) {
    if (data == null || data is! Map) return null;
    final errors = data['errors'] ?? data['detail'];
    if (errors is! Map) return null;

    return errors.map((key, value) => MapEntry(
          key.toString(),
          (value is List)
              ? value.map((e) => e.toString()).toList()
              : [value.toString()],
        ));
  }

  static int? _extractRetryAfter(Response? response) {
    final header = response?.headers.value('retry-after');
    if (header == null) return null;
    return int.tryParse(header);
  }
}

/// Network connectivity issues (offline, timeout)
final class NetworkException extends ApiException {
  const NetworkException({
    required super.message,
    super.originalError,
  }) : super(statusCode: null);

  /// Check if this is a connectivity issue (vs timeout)
  bool get isOffline => message.toLowerCase().contains('no internet');
}

/// Authentication/Authorization errors (401, 403)
final class AuthException extends ApiException {
  const AuthException({
    required super.message,
    super.statusCode,
    super.originalError,
  });

  /// True if token expired (401), false if permission denied (403)
  bool get isTokenExpired => statusCode == 401;
}

/// Validation errors (400, 422) with field-level details
final class ValidationException extends ApiException {
  final Map<String, List<String>>? fieldErrors;

  const ValidationException({
    required super.message,
    super.statusCode,
    this.fieldErrors,
    super.originalError,
  });

  /// Get error message for a specific field
  String? getFieldError(String field) => fieldErrors?[field]?.first;

  /// Check if a specific field has an error
  bool hasFieldError(String field) => fieldErrors?.containsKey(field) ?? false;
}

/// Resource not found (404)
final class NotFoundException extends ApiException {
  const NotFoundException({
    required super.message,
    super.statusCode,
    super.originalError,
  });
}

/// Rate limiting (429)
final class RateLimitException extends ApiException {
  final int? retryAfterSeconds;

  const RateLimitException({
    required super.message,
    super.statusCode,
    this.retryAfterSeconds,
    super.originalError,
  });
}

/// Server errors (5xx)
final class ServerException extends ApiException {
  const ServerException({
    required super.message,
    super.statusCode,
    super.originalError,
  });
}

/// Unknown/unexpected errors
final class UnknownApiException extends ApiException {
  const UnknownApiException({
    required super.message,
    super.statusCode,
    super.originalError,
  });
}
