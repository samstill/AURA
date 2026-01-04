/// Project Aura - Theme Controller
/// ================================
/// Riverpod provider for managing theme mode (light/dark/system).
/// Creates a hook for future settings integration.
///
/// Usage:
/// ```dart
/// // Read current theme mode
/// final themeMode = ref.watch(themeModeProvider);
///
/// // Change theme mode
/// ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.dark);
/// ref.read(themeModeProvider.notifier).setSystem();
/// ref.read(themeModeProvider.notifier).setLight();
/// ref.read(themeModeProvider.notifier).setDark();
/// ref.read(themeModeProvider.notifier).toggle();
/// ```
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider for the current theme mode
final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

/// Notifier that manages theme mode state
class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    return ThemeMode.system;
  }

  /// Set theme mode directly
  void setThemeMode(ThemeMode mode) {
    state = mode;
  }

  /// Set to system theme (follows device settings)
  void setSystem() {
    state = ThemeMode.system;
  }

  /// Set to light theme
  void setLight() {
    state = ThemeMode.light;
  }

  /// Set to dark theme
  void setDark() {
    state = ThemeMode.dark;
  }

  /// Toggle between light and dark (ignores system)
  void toggle() {
    if (state == ThemeMode.dark) {
      state = ThemeMode.light;
    } else {
      state = ThemeMode.dark;
    }
  }

  /// Cycle through: system -> light -> dark -> system
  void cycle() {
    switch (state) {
      case ThemeMode.system:
        state = ThemeMode.light;
        break;
      case ThemeMode.light:
        state = ThemeMode.dark;
        break;
      case ThemeMode.dark:
        state = ThemeMode.system;
        break;
    }
  }
}

/// Provider that determines if the current effective theme is dark
/// Takes into account both the theme mode setting and system brightness
final isDarkModeProvider = Provider<bool>((ref) {
  final themeMode = ref.watch(themeModeProvider);

  switch (themeMode) {
    case ThemeMode.dark:
      return true;
    case ThemeMode.light:
      return false;
    case ThemeMode.system:
      // This will be overridden by the widget that has access to MediaQuery
      // Default to dark for "The Void" aesthetic
      return true;
  }
});

/// Extension to get theme mode label for settings UI
extension ThemeModeExtension on ThemeMode {
  String get label {
    switch (this) {
      case ThemeMode.system:
        return 'System';
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
    }
  }

  String get description {
    switch (this) {
      case ThemeMode.system:
        return 'Follow system settings';
      case ThemeMode.light:
        return 'The Mirage - Warm & Biological';
      case ThemeMode.dark:
        return 'The Void - Cold & Infinite';
    }
  }
}
