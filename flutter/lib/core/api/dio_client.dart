/// Project Aura - Dio HTTP Client
/// ================================
/// Centralized Dio instance with security interceptors.
/// 
/// Security features:
/// - Bearer token injection via AuthInterceptor
/// - Automatic token refresh on 401
/// - Certificate pinning for auth.encresa.com (release builds)
/// - Typed API exceptions for structured error handling
/// - Request logging in development mode only
library;

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../auth/data/auth_repository.dart';
import '../config/app_config.dart';
import 'auth_interceptor.dart';
import 'certificate_pinning.dart';
import 'cookie_store/cookie_store.dart';

part 'dio_client.g.dart';

/// Secure storage instance for token management
const _secureStorage = FlutterSecureStorage(
  aOptions: AndroidOptions(encryptedSharedPreferences: true),
  iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
);

/// Provides the persistent CookieJar instance (or in-memory on Web)
@Riverpod(keepAlive: true)
Future<CookieJar> cookieJar(Ref ref) async {
  return makeCookieJar();
}

/// Provides the configured Dio instance for API calls
/// 
/// This client includes:
/// - AuthInterceptor for Bearer token injection
/// - Automatic token refresh on 401
/// - Structured error logging
@Riverpod(keepAlive: true)
Future<Dio> apiClient(Ref ref) async {
  final cookieJar = await ref.watch(cookieJarProvider.future);
  final authRepo = await ref.watch(authRepositoryProvider.future);
  
  final dio = Dio(BaseOptions(
    baseUrl: AppConfig.apiBaseUrl,
    // Production-ready timeouts
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 30),
    sendTimeout: const Duration(seconds: 15),
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      // Security headers
      'X-Requested-With': 'XMLHttpRequest',
    },
    // Let interceptors handle error responses
    validateStatus: (status) => status != null && status < 500,
  ));
  
  // Cookie manager for web session handling
  dio.interceptors.add(CookieManager(cookieJar));
  
  // Auth interceptor for Bearer token injection and refresh
  dio.interceptors.add(AuthInterceptor(
    storage: _secureStorage,
    refreshTokenFn: (refreshToken) async {
      try {
        final result = await authRepo.refreshTokensWithAuthentik(refreshToken);
        return result;
      } catch (e) {
        debugPrint('❌ [DioClient] Token refresh failed: $e');
        return null;
      }
    },
    onLogout: () async {
      debugPrint('🚪 [DioClient] Forced logout triggered');
      await authRepo.clearSession();
      // Note: GoRouter will handle navigation via auth state listener
    },
  ));
  
  // Debug logging in development only
  if (kDebugMode) {
    dio.interceptors.add(LogInterceptor(
      request: true,
      requestHeader: false, // Don't log auth headers
      requestBody: true,
      responseBody: true,
      responseHeader: false,
      error: true,
      logPrint: (obj) => debugPrint('[API] $obj'),
    ));
  }
  
  return dio;
}

/// Provides the configured Dio instance for Authentik API calls
/// 
/// This client is specifically for Authentik Flows API.
/// Does NOT use AuthInterceptor (would cause circular dependency).
/// Includes certificate pinning for auth.encresa.com in production.
@Riverpod(keepAlive: true)
Future<Dio> authentikClient(Ref ref) async {
  final cookieJar = await ref.watch(cookieJarProvider.future);
  
  final dio = Dio(BaseOptions(
    baseUrl: AppConfig.authentikBaseUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 30),
    sendTimeout: const Duration(seconds: 15),
    followRedirects: false,
    maxRedirects: 0,
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    },
    validateStatus: (status) => status != null && status < 500,
  ));
  
  // Configure certificate pinning for auth.encresa.com (release builds only)
  if (CertificatePins.isEnabled && !kIsWeb) {
    dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () {
        final client = HttpClient();
        client.badCertificateCallback = (cert, host, port) {
          final pins = CertificatePins.pinnedHosts[host];
          if (pins == null || pins.isEmpty) return true;
          
          // Get SHA256 of the certificate
          final certSha256 = _getCertSha256(cert);
          final isValid = pins.contains(certSha256);
          
          if (!isValid) {
            debugPrint('❌ [Security] Certificate pin mismatch for $host');
          }
          return isValid;
        };
        return client;
      },
    );
    debugPrint('🔒 [Auth] Certificate pinning enabled for auth.encresa.com');
  }
  
  // Cookie manager for session handling
  dio.interceptors.add(CookieManager(cookieJar));
  
  // Debug logging in development
  if (kDebugMode) {
    dio.interceptors.add(LogInterceptor(
      request: true,
      requestHeader: false,
      requestBody: true,
      responseBody: true,
      responseHeader: false,
      error: true,
      logPrint: (obj) => debugPrint('[Auth] $obj'),
    ));
  }
  
  return dio;
}

/// Helper to get base64-encoded SHA256 of certificate
String _getCertSha256(X509Certificate cert) {
  return CertificatePins.getCertificateSha256(cert.der);
}


