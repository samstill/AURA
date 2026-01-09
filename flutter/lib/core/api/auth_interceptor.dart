/// Project Aura - Auth Interceptor
/// ================================
/// Dio interceptor for secure Bearer token injection and automatic refresh.
///
/// Security features:
/// - Injects access token from secure storage into all API requests
/// - Handles 401 responses by attempting token refresh
/// - Queues concurrent requests during refresh to prevent race conditions
/// - Forces logout on refresh failure
library;

import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'api_exception.dart';

/// Callback type for triggering logout when auth fails
typedef LogoutCallback = Future<void> Function();

/// Auth interceptor that handles Bearer token injection and refresh
class AuthInterceptor extends QueuedInterceptorsWrapper {
  final FlutterSecureStorage _storage;
  final Future<Map<String, dynamic>?> Function(String refreshToken)?
      _refreshTokenFn;
  final LogoutCallback? _onLogout;

  // Storage keys
  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';
  static const _expiresAtKey = 'expires_at';

  // Lock for token refresh to prevent race conditions
  bool _isRefreshing = false;
  final List<(RequestOptions, ErrorInterceptorHandler)> _pendingRequests = [];

  AuthInterceptor({
    FlutterSecureStorage? storage,
    Future<Map<String, dynamic>?> Function(String refreshToken)? refreshTokenFn,
    LogoutCallback? onLogout,
  })  : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions:
                  IOSOptions(accessibility: KeychainAccessibility.first_unlock),
            ),
        _refreshTokenFn = refreshTokenFn,
        _onLogout = onLogout;

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Skip auth header for certain paths
    if (_shouldSkipAuth(options.path)) {
      return handler.next(options);
    }

    try {
      final token = await _getValidAccessToken();
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
      handler.next(options);
    } catch (e) {
      debugPrint('❌ [AuthInterceptor] Failed to get token: $e');
      handler.next(options);
    }
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    // Only handle 401 Unauthorized
    if (err.response?.statusCode != 401) {
      return handler.next(err);
    }

    // Skip retry for auth-related endpoints
    if (_shouldSkipAuth(err.requestOptions.path)) {
      return handler.next(err);
    }

    debugPrint('🔐 [AuthInterceptor] 401 received, attempting refresh...');

    // If already refreshing, queue this request
    if (_isRefreshing) {
      debugPrint('⏳ [AuthInterceptor] Queueing request during refresh');
      _pendingRequests.add((err.requestOptions, handler));
      return;
    }

    _isRefreshing = true;

    try {
      final refreshed = await _refreshTokens();

      if (refreshed) {
        debugPrint('✅ [AuthInterceptor] Token refreshed, retrying request');
        // Retry the original request with new token
        final retryResponse = await _retryRequest(err.requestOptions);
        handler.resolve(retryResponse);

        // Process queued requests
        await _processQueuedRequests(success: true);
      } else {
        debugPrint('❌ [AuthInterceptor] Token refresh failed, forcing logout');
        await _forceLogout();
        handler.next(err);
        await _processQueuedRequests(success: false);
      }
    } catch (e) {
      debugPrint('❌ [AuthInterceptor] Error during refresh: $e');
      await _forceLogout();
      handler.next(err);
      await _processQueuedRequests(success: false);
    } finally {
      _isRefreshing = false;
    }
  }

  /// Get a valid access token, refreshing if expired
  Future<String?> _getValidAccessToken() async {
    final token = await _storage.read(key: _accessTokenKey);
    if (token == null) return null;

    // Check if token is expired (with 30 second buffer)
    final expiresAtStr = await _storage.read(key: _expiresAtKey);
    if (expiresAtStr != null) {
      final expiresAt = DateTime.parse(expiresAtStr);
      if (DateTime.now().isAfter(expiresAt.subtract(const Duration(seconds: 30)))) {
        debugPrint('⚠️ [AuthInterceptor] Token expired, will refresh on 401');
        // Don't proactively refresh here - let the 401 trigger it
        // This avoids unnecessary refresh calls
      }
    }

    return token;
  }

  /// Attempt to refresh tokens using the refresh token
  Future<bool> _refreshTokens() async {
    final refreshToken = await _storage.read(key: _refreshTokenKey);
    if (refreshToken == null) {
      debugPrint('❌ [AuthInterceptor] No refresh token available');
      return false;
    }

    if (_refreshTokenFn == null) {
      debugPrint('❌ [AuthInterceptor] No refresh function configured');
      return false;
    }

    try {
      final tokens = await _refreshTokenFn!(refreshToken);
      if (tokens == null) return false;

      await _saveTokens(tokens);
      return true;
    } catch (e) {
      debugPrint('❌ [AuthInterceptor] Refresh failed: $e');
      return false;
    }
  }

  /// Save tokens to secure storage
  Future<void> _saveTokens(Map<String, dynamic> tokens) async {
    final accessToken = tokens['access_token'] as String?;
    final refreshToken = tokens['refresh_token'] as String?;
    final expiresIn = tokens['expires_in'] as int?;

    if (accessToken != null) {
      await _storage.write(key: _accessTokenKey, value: accessToken);
    }
    if (refreshToken != null) {
      await _storage.write(key: _refreshTokenKey, value: refreshToken);
    }
    if (expiresIn != null) {
      final expiresAt = DateTime.now().add(Duration(seconds: expiresIn));
      await _storage.write(key: _expiresAtKey, value: expiresAt.toIso8601String());
    }

    debugPrint('💾 [AuthInterceptor] Tokens saved');
  }

  /// Retry a request with the new token
  Future<Response> _retryRequest(RequestOptions requestOptions) async {
    final token = await _storage.read(key: _accessTokenKey);
    requestOptions.headers['Authorization'] = 'Bearer $token';

    final dio = Dio(BaseOptions(
      baseUrl: requestOptions.baseUrl,
      connectTimeout: requestOptions.connectTimeout,
      receiveTimeout: requestOptions.receiveTimeout,
    ));

    return dio.fetch(requestOptions);
  }

  /// Process all queued requests after refresh completes
  Future<void> _processQueuedRequests({required bool success}) async {
    final requests = List.of(_pendingRequests);
    _pendingRequests.clear();

    for (final (options, handler) in requests) {
      if (success) {
        try {
          final response = await _retryRequest(options);
          handler.resolve(response);
        } catch (e) {
          handler.reject(DioException(
            requestOptions: options,
            error: e,
          ));
        }
      } else {
        handler.reject(DioException(
          requestOptions: options,
          error: AuthException(message: 'Session expired'),
        ));
      }
    }
  }

  /// Force logout and clear all tokens
  Future<void> _forceLogout() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
    await _storage.delete(key: _expiresAtKey);

    if (_onLogout != null) {
      await _onLogout!();
    }

    debugPrint('🚪 [AuthInterceptor] Forced logout complete');
  }

  /// Check if auth should be skipped for this path
  bool _shouldSkipAuth(String path) {
    // Skip auth for Authentik-related paths and public endpoints
    return path.contains('/api/v3/flows/') ||
        path.contains('/health') ||
        path.contains('/docs');
  }
}
