/// Project Aura - Main Application Entry Point
/// ============================================
/// Feature-first architecture with Riverpod 2.0 and GoRouter.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/aura_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
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
    
    return MaterialApp.router(
      title: 'Project Aura',
      debugShowCheckedModeBanner: false,
      theme: AuraTheme.lightTheme,
      darkTheme: AuraTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
