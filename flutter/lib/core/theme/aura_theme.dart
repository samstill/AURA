/// Project Aura - Theme Constants
/// ===============================
/// Design tokens for the Aura brand.

import 'package:flutter/material.dart';

/// Brand colors and design tokens
class AuraTheme {
  AuraTheme._();
  
  // Primary brand color (Indigo)
  static const Color primary = Color(0xFF6366F1);
  static const Color primaryLight = Color(0xFF818CF8);
  static const Color primaryDark = Color(0xFF4F46E5);
  
  // Accent colors
  static const Color accent = Color(0xFF8B5CF6);
  static const Color tertiary = Color(0xFFEC4899);
  
  // Surface colors
  static const Color surface = Color(0xFFF8FAFC);
  static const Color surfaceDark = Color(0xFF1E293B);
  
  // Semantic colors
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  
  /// Light theme
  static ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
    ),
  );
  
  /// Dark theme  
  static ThemeData get darkTheme => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.dark,
    ),
  );
}
