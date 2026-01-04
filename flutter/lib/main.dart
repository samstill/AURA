/// Project Aura - Main Application Entry Point
/// ============================================
/// Feature-first architecture with Riverpod 2.0 and GoRouter.
/// Theme system follows the "Tactical Implementation of Desire" philosophy.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/design_system/design_system.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize persistence before starting the app
  await AuthChangeNotifier.instance.initialize();

  runApp(
    const ProviderScope(
      child: AuraApp(),
    ),
  );
}

class AuraApp extends ConsumerWidget {
  const AuraApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    // Watch the theme mode from the provider (defaults to system)
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'Project Aura',
      debugShowCheckedModeBanner: false,
      // The Mirage (Light Theme)
      theme: AppTheme.light,
      // The Void (Dark Theme)
      darkTheme: AppTheme.dark,
      // Controlled by themeModeProvider - defaults to system
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
