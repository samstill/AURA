/// Project Aura - Auth Repository
/// ===============================
/// Handles authentication via Authentik Flows API.

import 'dart:convert';
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
AuthRepository authRepository(AuthRepositoryRef ref) {
  return AuthRepository(
    client: ref.watch(authentikClientProvider),
    storage: const FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
      iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
    ),
  );
}

/// Repository for authentication operations
class AuthRepository {
  final Dio client;
  final FlutterSecureStorage storage;

  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';
  static const _expiresAtKey = 'expires_at';

  AuthRepository({required this.client, required this.storage});

  /// Static lock to prevent multiple concurrent flow starts
  static bool _flowInProgress = false;
  static Future<FlowResult>? _pendingFlow;

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
    await storage.deleteAll();
    _flowInProgress = false;
    _pendingFlow = null;
    
    // Try to cancel any active flow
    try {
      await client.get('/flows/-/cancel/');
    } catch (e) {
      debugPrint('⚠️ Cancel endpoint failed: $e');
    }
  }
}
