/// Project Aura - Auth State Model
/// ================================
/// Immutable auth state using freezed.

import 'package:freezed_annotation/freezed_annotation.dart';

part 'auth_state.freezed.dart';
part 'auth_state.g.dart';

/// Authentication status
enum AuthStatus {
  initial,
  loading,
  authenticated,
  unauthenticated,
  error,
}

/// User model from Authentik
@freezed
class AuthUser with _$AuthUser {
  const factory AuthUser({
    required String id,
    required String email,
    @Default(false) bool emailVerified,
    required String name,
    required String username,
    @Default([]) List<String> groups,
  }) = _AuthUser;

  factory AuthUser.fromJson(Map<String, dynamic> json) => _$AuthUserFromJson(json);
}

/// Complete auth state
@freezed
class AuthState with _$AuthState {
  const AuthState._();
  
  const factory AuthState({
    @Default(AuthStatus.initial) AuthStatus status,
    AuthUser? user,
    String? accessToken,
    String? refreshToken,
    String? error,
  }) = _AuthState;

  bool get isAuthenticated => status == AuthStatus.authenticated && user != null;
  bool get isLoading => status == AuthStatus.loading;
}
