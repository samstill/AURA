/// Project Aura - App Router
/// ==========================
/// GoRouter configuration with auth guards and route definitions.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/dashboard/presentation/screens/home_screen.dart';
import '../auth/presentation/screens/login_screen.dart';
import '../auth/presentation/controllers/auth_controller.dart';

part 'app_router.g.dart';

/// Route paths
class AppRoutes {
  static const String login = '/login';
  static const String home = '/';
  static const String chat = '/chat';
}

/// GoRouter provider
@riverpod
GoRouter appRouter(AppRouterRef ref) {
  final authState = ref.watch(authControllerProvider);
  
  return GoRouter(
    initialLocation: AppRoutes.login,
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final isAuthenticated = authState.valueOrNull?.isAuthenticated ?? false;
      final isLoggingIn = state.matchedLocation == AppRoutes.login;
      
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
}
