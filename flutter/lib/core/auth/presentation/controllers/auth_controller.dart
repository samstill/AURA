/// Project Aura - Auth Controller
/// ===============================
/// AsyncNotifier for authentication state management.

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/data.dart';
import '../../domain/domain.dart';
import '../../../router/app_router.dart';

part 'auth_controller.g.dart';

/// Auth state controller using AsyncNotifier
@riverpod
class AuthController extends _$AuthController {
  /// Static lock to prevent multiple concurrent flow starts
  static bool _flowInProgress = false;
  static Future<FlowResult>? _pendingFlow;
  
  @override
  Future<AuthState> build() async {
    // Check for existing tokens on startup
    final repo = ref.read(authRepositoryProvider);
    final token = await repo.getAccessToken();
    
    if (token != null && !(await repo.isTokenExpired())) {
      return const AuthState(status: AuthStatus.authenticated);
    }
    
    return const AuthState(status: AuthStatus.unauthenticated);
  }

  /// Current flow challenge
  FlowChallenge? _currentChallenge;
  FlowChallenge? get currentChallenge => _currentChallenge;

  /// Start authentication flow (with static lock)
  Future<FlowResult> startAuthFlow() async {
    // If a flow is already in progress, return the pending result
    if (_flowInProgress && _pendingFlow != null) {
      debugPrint('⏳ Flow already in progress, waiting...');
      return _pendingFlow!;
    }
    
    _flowInProgress = true;
    debugPrint('🔐 Starting authentication flow (locked)');
    
    _pendingFlow = _doStartFlow();
    final result = await _pendingFlow!;
    
    _flowInProgress = false;
    _pendingFlow = null;
    
    return result;
  }

  /// Restart authentication flow - resets state and starts fresh
  Future<FlowResult> restartAuthFlow() async {
    debugPrint('🔄 Restarting authentication flow...');
    
    // Reset both controller and repository locks
    _flowInProgress = false;
    _pendingFlow = null;
    _currentChallenge = null;
    
    final repo = ref.read(authRepositoryProvider);
    await repo.resetFlow();
    
    // Now start fresh
    return startAuthFlow();
  }
  
  Future<FlowResult> _doStartFlow() async {
    final repo = ref.read(authRepositoryProvider);
    final result = await repo.startFlow();
    
    if (result.success && result.challenge != null) {
      _currentChallenge = result.challenge;
    }
    
    return result;
  }

  /// Submit identification
  Future<FlowResult> submitIdentification(String email) async {
    final repo = ref.read(authRepositoryProvider);
    final result = await repo.submitIdentification(email);
    
    if (result.success && result.challenge != null) {
      _currentChallenge = result.challenge;
      
      if (result.challenge!.isSuccess) {
        await _onLoginSuccess();
      }
    }
    
    return result;
  }

  /// Submit password
  Future<FlowResult> submitPassword(String password) async {
    final repo = ref.read(authRepositoryProvider);
    final result = await repo.submitPassword(password);
    
    if (result.success && result.challenge != null) {
      _currentChallenge = result.challenge;
      
      if (result.challenge!.isSuccess) {
        await _onLoginSuccess();
      }
    }
    
    return result;
  }

  /// Submit TOTP
  Future<FlowResult> submitTotp(String code) async {
    final repo = ref.read(authRepositoryProvider);
    final result = await repo.submitTotp(code);
    
    if (result.success && result.challenge != null) {
      _currentChallenge = result.challenge;
      
      if (result.challenge!.isSuccess) {
        await _onLoginSuccess();
      }
    }
    
    return result;
  }

  /// Handle successful login
  Future<void> _onLoginSuccess() async {
    debugPrint('✅ Login successful!');
    state = const AsyncData(AuthState(status: AuthStatus.authenticated));
    
    // Notify the router's auth listener to trigger redirect
    // Import is done dynamically to avoid circular dependency
    AuthChangeNotifier.instance.setAuthenticated(true);
  }

  /// Logout
  Future<void> logout() async {
    final repo = ref.read(authRepositoryProvider);
    await repo.clearTokens();
    _currentChallenge = null;
    state = const AsyncData(AuthState(status: AuthStatus.unauthenticated));
    
    // Notify the router's auth listener
    AuthChangeNotifier.instance.setAuthenticated(false);
  }
}

/// Convenience providers
@riverpod
bool isAuthenticated(IsAuthenticatedRef ref) {
  return ref.watch(authControllerProvider).valueOrNull?.isAuthenticated ?? false;
}

@riverpod
FlowChallenge? currentChallenge(CurrentChallengeRef ref) {
  return ref.watch(authControllerProvider.notifier).currentChallenge;
}
