/// Project Aura - App Router
/// ==========================
/// GoRouter configuration with auth guards and route definitions.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/dashboard/presentation/screens/home_screen.dart';
import '../auth/presentation/screens/login_screen.dart';

part 'app_router.g.dart';

/// Route paths
class AppRoutes {
  static const String login = '/login';
  static const String home = '/';
  static const String chat = '/chat';
}

/// ValueNotifier that listens to auth state and notifies GoRouter
class AuthChangeNotifier extends ChangeNotifier {
  AuthChangeNotifier._();
  
  static final instance = AuthChangeNotifier._();
  
  bool _isAuthenticated = false;
  
  bool get isAuthenticated => _isAuthenticated;
  
  void setAuthenticated(bool value) {
    if (_isAuthenticated != value) {
      debugPrint('🔔 AuthChangeNotifier: isAuthenticated changed to $value');
      _isAuthenticated = value;
      notifyListeners();
    }
  }
}

/// Stable GoRouter instance - created once and reused
GoRouter? _routerInstance;

/// GoRouter provider - returns stable instance
@riverpod
GoRouter appRouter(AppRouterRef ref) {
  // Only create router once
  if (_routerInstance != null) {
    return _routerInstance!;
  }
  
  debugPrint('🧭 Creating GoRouter instance');
  
  _routerInstance = GoRouter(
    initialLocation: AppRoutes.login,
    debugLogDiagnostics: true,
    refreshListenable: AuthChangeNotifier.instance,
    redirect: (context, state) {
      final isAuthenticated = AuthChangeNotifier.instance.isAuthenticated;
      final isLoggingIn = state.matchedLocation == AppRoutes.login;
      
      debugPrint('🧭 Router redirect: authenticated=$isAuthenticated, location=${state.matchedLocation}');
      
      // Redirect to login if not authenticated
      if (!isAuthenticated && !isLoggingIn) {
        return AppRoutes.login;
      }
      
      // Redirect to home if already authenticated and on login page
      if (isAuthenticated && isLoggingIn) {
        return AppRoutes.home;
      }
      
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.home,
        name: 'home',
        builder: (context, state) => const HomeScreen(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Route not found: ${state.uri}'),
      ),
    ),
  );
  
  return _routerInstance!;
}

