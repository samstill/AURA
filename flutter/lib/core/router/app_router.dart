/// Project Aura - App Router
/// ==========================
/// GoRouter configuration with auth guards and route definitions.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/dashboard/presentation/screens/screens.dart';
import '../auth/presentation/screens/login_screen.dart';
import '../../features/splash/presentation/screens/splash_screen.dart';

part 'app_router.g.dart';

/// Route paths
class AppRoutes {
  static const String splash = '/splash';
  static const String login = '/login';
  static const String home = '/';
  static const String chat = '/chat';
  static const String tools = '/tools';
  static const String summary = '/summary';
}

/// ValueNotifier that listens to auth state and notifies GoRouter
class AuthChangeNotifier extends ChangeNotifier {
  AuthChangeNotifier._();
  
  static final instance = AuthChangeNotifier._();
  
  bool _isAuthenticated = false;
  bool _splashComplete = false;
  
  bool get isAuthenticated => _isAuthenticated;
  bool get splashComplete => _splashComplete;

  /// Initialize state from SharedPreferences (called from main)
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    // If we have seen the splash before, mark it as complete immediately
    _splashComplete = prefs.getBool('has_seen_splash') ?? false;
    debugPrint('🔔 AuthChangeNotifier: Initialized. Splash seen before: $_splashComplete');
    notifyListeners();
  }
  
  void setAuthenticated(bool value) {
    if (_isAuthenticated != value) {
      debugPrint('🔔 AuthChangeNotifier: isAuthenticated changed to $value');
      _isAuthenticated = value;
      notifyListeners();
    }
  }
  
  void setSplashComplete(bool value) {
    if (_splashComplete != value) {
      debugPrint('🔔 AuthChangeNotifier: splashComplete changed to $value');
      _splashComplete = value;
      notifyListeners();
      
      // Persist that we've seen the splash screen
      if (value) {
        SharedPreferences.getInstance().then((prefs) {
          prefs.setBool('has_seen_splash', true);
        });
      }
    }
  }
}

/// Stable GoRouter instance - created once and reused
GoRouter? _routerInstance;

/// GoRouter provider - returns stable instance
@riverpod
GoRouter appRouter(Ref ref) {
  // Only create router once
  if (_routerInstance != null) {
    return _routerInstance!;
  }
  
  debugPrint('🧭 Creating GoRouter instance');
  
  _routerInstance = GoRouter(
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: true,
    refreshListenable: AuthChangeNotifier.instance,
    redirect: (context, state) {
      final isAuthenticated = AuthChangeNotifier.instance.isAuthenticated;
      final splashComplete = AuthChangeNotifier.instance.splashComplete;
      final currentLocation = state.matchedLocation;
      
      debugPrint('🧭 Router redirect: authenticated=$isAuthenticated, splash=$splashComplete, location=$currentLocation');
      
      // If splash not complete, stay on splash
      if (!splashComplete && currentLocation != AppRoutes.splash) {
        return AppRoutes.splash;
      }
      
      // After splash completes, redirect based on auth
      if (splashComplete && currentLocation == AppRoutes.splash) {
        return isAuthenticated ? AppRoutes.home : AppRoutes.login;
      }
      
      // Normal auth redirects
      if (splashComplete) {
        if (!isAuthenticated && currentLocation != AppRoutes.login) {
          return AppRoutes.login;
        }
        if (isAuthenticated && currentLocation == AppRoutes.login) {
          return AppRoutes.home;
        }
      }
      
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        name: 'splash',
        builder: (context, state) => SplashScreen(
          duration: const Duration(seconds: 3),
          onComplete: () {
            AuthChangeNotifier.instance.setSplashComplete(true);
          },
        ),
      ),
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.home,
        name: 'home',
        builder: (context, state) => const DashboardShell(),
      ),
      GoRoute(
        path: '/profile', // Keeping for backward compat, or redirect to settings
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/settings/secretary',
        builder: (context, state) => const Scaffold(body: Center(child: Text("Edit Secretary Placeholder"))), // Placeholder
      ),
      GoRoute(
        path: '/settings/account',
        builder: (context, state) => const Scaffold(body: Center(child: Text("Account Settings Placeholder"))), // Placeholder
      ),
       GoRoute(
        path: '/settings/app',
        builder: (context, state) => const Scaffold(body: Center(child: Text("App Settings Placeholder"))), // Placeholder
      ),
      GoRoute(
        path: '/background-tasks',
        builder: (context, state) => const BackgroundTasksScreen(),
      ),
      GoRoute(
        path: AppRoutes.tools,
        builder: (context, state) => const ToolsScreen(),
      ),
      GoRoute(
        path: AppRoutes.summary,
        builder: (context, state) => const SummaryScreen(),
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


