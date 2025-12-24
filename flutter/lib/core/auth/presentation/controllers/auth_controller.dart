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
    // Check for existing session via backend validation
    // The repository is now an async provider, so we await its future
    final repo = await ref.watch(authRepositoryProvider.future);
    
    // Check if we have a valid session cookie
    final isValidSession = await repo.checkSession();
    
    if (isValidSession) {
      debugPrint('✅ Initial build: Authenticated session found');
      // Ensure the router knows we are authenticated immediately
      AuthChangeNotifier.instance.setAuthenticated(true);
      return const AuthState(status: AuthStatus.authenticated);
    }
    
    debugPrint('⚠️ Initial build: No valid session found');
    AuthChangeNotifier.instance.setAuthenticated(false);
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
    
    final repo = await ref.read(authRepositoryProvider.future);
    await repo.resetFlow();
    
    // Now start fresh
    return startAuthFlow();
  }
  
  Future<FlowResult> _doStartFlow() async {
    final repo = await ref.read(authRepositoryProvider.future);
    final result = await repo.startFlow();
    
    if (result.success && result.challenge != null) {
      _currentChallenge = result.challenge;
    }
    
    return result;
  }

  /// Submit identification
  Future<FlowResult> submitIdentification(String email) async {
    final repo = await ref.read(authRepositoryProvider.future);
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
    final repo = await ref.read(authRepositoryProvider.future);
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
    final repo = await ref.read(authRepositoryProvider.future);
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
    
    // Mark user as logged in for offline access
    final repo = await ref.read(authRepositoryProvider.future);
    await repo.markLoggedIn();
    
    state = const AsyncData(AuthState(status: AuthStatus.authenticated));
    
    // Notify the router's auth listener to trigger redirect
    AuthChangeNotifier.instance.setAuthenticated(true);
  }

  /// Logout
  Future<void> logout() async {
    debugPrint('🚪 initiating logout...');
    final repo = await ref.read(authRepositoryProvider.future);
    await repo.clearSession();
    
    _currentChallenge = null;
    state = const AsyncData(AuthState(status: AuthStatus.unauthenticated));
    
    // Notify the router's auth listener
    AuthChangeNotifier.instance.setAuthenticated(false);
    debugPrint('✅ Logout complete');
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
