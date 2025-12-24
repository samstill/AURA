/// Project Aura - Auth Repository
/// ===============================
/// Handles authentication via Authentik Flows API.

import 'dart:convert';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../api/dio_client.dart';
import '../../config/app_config.dart';
import '../domain/domain.dart';

part 'auth_repository.g.dart';

/// Result of a flow operation
class FlowResult {
  final bool success;
  final FlowChallenge? challenge;
  final FlowError? error;
  final String? accessToken;
  final String? refreshToken;

  FlowResult({
    required this.success,
    this.challenge,
    this.error,
    this.accessToken,
    this.refreshToken,
  });

  bool get needsMoreInput => challenge != null && !challenge!.isSuccess && !challenge!.isAccessDenied;
}

/// Auth repository provider
@Riverpod(keepAlive: true)
Future<AuthRepository> authRepository(AuthRepositoryRef ref) async {
  final client = await ref.watch(authentikClientProvider.future);
  final cookieJar = await ref.watch(cookieJarProvider.future);
  
  return AuthRepository(
    client: client,
    cookieJar: cookieJar,
    storage: const FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
      iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
    ),
  );
}

/// Repository for authentication operations
class AuthRepository {
  final Dio client;
  final CookieJar cookieJar;
  final FlutterSecureStorage storage;

  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';
  static const _expiresAtKey = 'expires_at';
  static const _lastLoginKey = 'last_login_timestamp';
  static const _isLoggedInKey = 'is_logged_in';
  
  /// Offline grace period - user can access dashboard without backend validation
  /// for this duration after last successful login
  static const Duration offlineGracePeriod = Duration(days: 7);

  AuthRepository({
    required this.client, 
    required this.cookieJar,
    required this.storage,
  });

  /// Static lock to prevent multiple concurrent flow starts
  static bool _flowInProgress = false;
  static Future<FlowResult>? _pendingFlow;

  /// Check if the session is valid - first checks local timestamp, then backend
  Future<bool> checkSession() async {
    debugPrint('🔍 Checking session validity...');
    
    // First check if we have a valid local session within grace period
    final hasLocalSession = await _hasValidLocalSession();
    if (hasLocalSession) {
      debugPrint('✅ Valid local session found (within offline grace period)');
      
      // Try to validate with backend in background, but don't block
      _validateSessionInBackground();
      return true;
    }
    
    // No valid local session - must validate with backend
    return await _validateSessionWithBackend();
  }
  
  /// Check if we have a valid local session within the offline grace period
  Future<bool> _hasValidLocalSession() async {
    try {
      final isLoggedIn = await storage.read(key: _isLoggedInKey);
      if (isLoggedIn != 'true') {
        debugPrint('⚠️ No local login flag found');
        return false;
      }
      
      final lastLoginStr = await storage.read(key: _lastLoginKey);
      if (lastLoginStr == null) {
        debugPrint('⚠️ No last login timestamp found');
        return false;
      }
      
      final lastLogin = DateTime.parse(lastLoginStr);
      final now = DateTime.now();
      final elapsed = now.difference(lastLogin);
      
      if (elapsed <= offlineGracePeriod) {
        debugPrint('✅ Local session valid (${elapsed.inDays} days since login, grace period: ${offlineGracePeriod.inDays} days)');
        return true;
      }
      
      debugPrint('⚠️ Local session expired (${elapsed.inDays} days since login)');
      return false;
    } catch (e) {
      debugPrint('❌ Error checking local session: $e');
      return false;
    }
  }
  
  /// Validate session with backend (for online scenarios)
  Future<bool> _validateSessionWithBackend() async {
    debugPrint('🔍 Validating session with backend...');
    try {
      final response = await client.get('/api/v3/core/users/me/');
      
      if (response.statusCode == 200) {
        debugPrint('✅ Session is valid: ${response.data['username']}');
        // Update local session timestamp on successful validation
        await _saveLocalSession();
        return true;
      }
      debugPrint('⚠️ Session check failed: ${response.statusCode}');
      return false;
    } catch (e) {
      debugPrint('❌ Session check error: $e');
      return false;
    }
  }
  
  /// Validate session in background (non-blocking)
  Future<void> _validateSessionInBackground() async {
    debugPrint('🔄 Background session validation...');
    try {
      final response = await client.get('/api/v3/core/users/me/');
      if (response.statusCode == 200) {
        debugPrint('✅ Background validation successful');
        await _saveLocalSession();
      } else {
        debugPrint('⚠️ Background validation failed - session may be invalid');
        // Don't clear local session here - let user continue with offline access
      }
    } catch (e) {
      debugPrint('⚠️ Background validation error (offline?): $e');
      // Don't clear local session - user can continue offline
    }
  }
  
  /// Save local session timestamp
  Future<void> _saveLocalSession() async {
    await storage.write(key: _isLoggedInKey, value: 'true');
    await storage.write(key: _lastLoginKey, value: DateTime.now().toIso8601String());
    debugPrint('💾 Local session saved');
  }
  
  /// Mark user as logged in after successful authentication
  Future<void> markLoggedIn() async {
    await _saveLocalSession();
    debugPrint('✅ User marked as logged in for offline access');
  }

  /// Reset flow state - call before starting a new flow when user wants to restart
  Future<void> resetFlow() async {
    debugPrint('🔄 Resetting flow state...');
    _flowInProgress = false;
    _pendingFlow = null;
    
    // Try to cancel the current flow in Authentik
    try {
      debugPrint('🚫 Calling Authentik cancel endpoint...');
      await client.get('/flows/-/cancel/');
    } catch (e) {
      // Ignore errors - the cancel might fail if no flow is in progress
      debugPrint('⚠️ Cancel endpoint failed (expected if no flow): $e');
    }
  }

  /// Clear all session data - use for complete logout
  Future<void> clearSession() async {
    debugPrint('🗑️ Clearing all session data...');
    _flowInProgress = false;
    _pendingFlow = null;
    await storage.deleteAll();
    
    // Clear cookies
    await cookieJar.deleteAll();
    debugPrint('🍪 Cookies cleared');
    
    // Try to cancel any active flow
    try {
      await client.get('/flows/-/cancel/');
    } catch (e) {
      debugPrint('⚠️ Cancel endpoint failed: $e');
    }
  }

  /// Start a new authentication flow
  Future<FlowResult> startFlow({String? flowSlug}) async {
    // If a flow is already in progress, return the pending result
    if (_flowInProgress && _pendingFlow != null) {
      debugPrint('⏳ Flow already in progress, returning pending...');
      return _pendingFlow!;
    }
    
    _flowInProgress = true;
    _pendingFlow = _doStartFlow(flowSlug);
    
    try {
      final result = await _pendingFlow!;
      return result;
    } finally {
      _flowInProgress = false;
      _pendingFlow = null;
    }
  }
  
  Future<FlowResult> _doStartFlow(String? flowSlug) async {
    final slug = flowSlug ?? AppConfig.authFlowSlug;
    debugPrint('🔐 Starting authentication flow (locked): $slug');

    try {
      final response = await client.get('/api/v3/flows/executor/$slug/');
      return _handleFlowResponse(response);
    } catch (e) {
      debugPrint('❌ Flow start error: $e');
      return FlowResult(
        success: false,
        error: FlowError(nonFieldErrors: e.toString()),
      );
    }
  }

  /// Submit identification (username/email)
  Future<FlowResult> submitIdentification(String uidField) async {
    debugPrint('📧 Submitting identification: $uidField');
    
    try {
      final response = await client.post(
        '/api/v3/flows/executor/${AppConfig.authFlowSlug}/',
        data: {'uid_field': uidField},
      );
      
      var result = _handleFlowResponse(response);
      
      if (result.error?.nonFieldErrors == '_CONTINUE_FLOW_') {
        return await _fetchCurrentStage();
      }
      
      return result;
    } catch (e) {
      debugPrint('❌ Identification error: $e');
      return FlowResult(success: false, error: FlowError(nonFieldErrors: e.toString()));
    }
  }

  /// Submit password
  Future<FlowResult> submitPassword(String password) async {
    debugPrint('🔑 Submitting password');
    
    try {
      final response = await client.post(
        '/api/v3/flows/executor/${AppConfig.authFlowSlug}/',
        data: {'password': password},
      );
      
      var result = _handleFlowResponse(response);
      
      if (result.error?.nonFieldErrors == '_CONTINUE_FLOW_') {
        return await _fetchCurrentStage();
      }
      
      return result;
    } catch (e) {
      debugPrint('❌ Password error: $e');
      return FlowResult(success: false, error: FlowError(nonFieldErrors: e.toString()));
    }
  }

  /// Submit TOTP code
  Future<FlowResult> submitTotp(String code) async {
    debugPrint('🔢 Submitting TOTP code');
    
    try {
      final response = await client.post(
        '/api/v3/flows/executor/${AppConfig.authFlowSlug}/',
        data: {'code': code},
      );
      
      var result = _handleFlowResponse(response);
      
      if (result.error?.nonFieldErrors == '_CONTINUE_FLOW_') {
        return await _fetchCurrentStage();
      }
      
      return result;
    } catch (e) {
      debugPrint('❌ TOTP error: $e');
      return FlowResult(success: false, error: FlowError(nonFieldErrors: e.toString()));
    }
  }

  /// Fetch the current flow stage (with retry for chained redirects)
  Future<FlowResult> _fetchCurrentStage({int retryCount = 0}) async {
    debugPrint('🔄 Fetching current flow stage... (attempt ${retryCount + 1})');
    
    if (retryCount >= 5) {
      debugPrint('❌ Max retries reached for fetching stage');
      return FlowResult(success: false, error: FlowError(nonFieldErrors: 'Max retries reached'));
    }
    
    try {
      final response = await client.get(
        '/api/v3/flows/executor/${AppConfig.authFlowSlug}/',
      );
      
      final result = _handleFlowResponse(response);
      
      // If we get another "continue flow", retry
      if (result.error?.nonFieldErrors == '_CONTINUE_FLOW_') {
        await Future.delayed(const Duration(milliseconds: 100));
        return _fetchCurrentStage(retryCount: retryCount + 1);
      }
      
      return result;
    } catch (e) {
      debugPrint('❌ Fetch stage error: $e');
      return FlowResult(success: false, error: FlowError(nonFieldErrors: e.toString()));
    }
  }

  /// Handle the flow response
  FlowResult _handleFlowResponse(Response response) {
    debugPrint('📩 Flow response: ${response.statusCode}');
    
    // Handle 302/303 redirects
    if (response.statusCode == 302 || response.statusCode == 303) {
      final location = response.headers.value('location');
      debugPrint('🔀 Redirect to: $location');
      
      if (location != null && location.contains('/api/v3/flows/executor/')) {
        debugPrint('📍 Flow continuation, fetching next stage...');
        return FlowResult(
          success: true,
          challenge: null,
          error: FlowError(nonFieldErrors: '_CONTINUE_FLOW_'),
        );
      }
      
      debugPrint('✅ Authentication complete!');
      return FlowResult(
        success: true,
        challenge: RedirectChallenge(
          component: FlowComponentType.redirect,
          rawData: {'to': location},
          redirectTo: location,
        ),
      );
    }
    
    // Handle non-JSON responses
    if (response.data is String) {
      final dataStr = response.data as String;
      
      if (dataStr.isEmpty || dataStr.length < 10) {
        return FlowResult(success: false, error: FlowError(nonFieldErrors: 'Empty response'));
      }
      
      if (dataStr.contains('<!DOCTYPE') || dataStr.contains('<html')) {
        return FlowResult(success: false, error: FlowError(nonFieldErrors: 'Server returned HTML'));
      }
      
      try {
        final data = jsonDecode(dataStr) as Map<String, dynamic>;
        return _processJsonResponse(data);
      } catch (e) {
        return FlowResult(success: false, error: FlowError(nonFieldErrors: 'Invalid response'));
      }
    }
    
    final data = response.data as Map<String, dynamic>?;
    if (data == null) {
      return FlowResult(success: false, error: FlowError(nonFieldErrors: 'Empty response'));
    }

    return _processJsonResponse(data);
  }

  FlowResult _processJsonResponse(Map<String, dynamic> data) {
    debugPrint('📦 Processing JSON response: ${data.keys.toList()}');
    debugPrint('📦 Component field: ${data['component']}');
    
    if (data.containsKey('response_errors')) {
      final errors = data['response_errors'] as Map<String, dynamic>?;
      if (errors != null && errors.isNotEmpty) {
        return FlowResult(
          success: false,
          error: FlowError.fromJson(errors),
          challenge: FlowChallenge.fromJson(data),
        );
      }
    }

    final challenge = FlowChallenge.fromJson(data);
    debugPrint('📦 Parsed challenge type: ${challenge.component.value}');

    if (challenge is RedirectChallenge) {
      debugPrint('✅ Flow completed successfully!');
      return FlowResult(success: true, challenge: challenge);
    }

    if (challenge is AccessDeniedChallenge) {
      debugPrint('❌ Access denied: ${challenge.errorMessage}');
      return FlowResult(
        success: false,
        challenge: challenge,
        error: FlowError(nonFieldErrors: challenge.errorMessage ?? 'Access denied'),
      );
    }

    debugPrint('📝 Next stage: ${challenge.component.value}');
    return FlowResult(success: true, challenge: challenge);
  }

  // Token storage methods
  Future<void> saveTokens({
    required String accessToken,
    String? refreshToken,
    required int expiresIn,
  }) async {
    await storage.write(key: _accessTokenKey, value: accessToken);
    if (refreshToken != null) {
      await storage.write(key: _refreshTokenKey, value: refreshToken);
    }
    final expiresAt = DateTime.now().add(Duration(seconds: expiresIn));
    await storage.write(key: _expiresAtKey, value: expiresAt.toIso8601String());
    debugPrint('💾 Tokens saved');
  }

  Future<String?> getAccessToken() async {
    return await storage.read(key: _accessTokenKey);
  }

  Future<String?> getRefreshToken() async {
    return await storage.read(key: _refreshTokenKey);
  }

  Future<bool> isTokenExpired() async {
    final expiresAtStr = await storage.read(key: _expiresAtKey);
    if (expiresAtStr == null) return true;
    
    final expiresAt = DateTime.parse(expiresAtStr);
    return DateTime.now().isAfter(expiresAt.subtract(const Duration(minutes: 5)));
  }

  Future<void> clearTokens() async {
    debugPrint('🚪 Clearing tokens and session...');
    await clearSession();
  }
}
