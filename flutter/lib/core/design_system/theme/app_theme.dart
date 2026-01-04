/// Project Aura - Theme Factory
/// =============================
/// Assembles ThemeData with semantic colors, typography, and Material3.
/// Ensures instant theme switching between Void (dark) and Mirage (light).
library;

import 'package:flutter/material.dart';
import 'aura_colors.dart';
import 'aura_typography.dart';

class AppTheme {
  AppTheme._();

  /// Generates a complete ThemeData for the given brightness.
  static ThemeData define(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final auraColors = isDark ? AuraColors.voidTheme : AuraColors.mirageTheme;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: auraColors.bgPrimary,

      // Inject our Semantic Palette as ThemeExtension
      extensions: [auraColors],

      // Standard Material ColorScheme mapping for compatibility
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: AuraColors.heartbeat,
        onPrimary: Colors.white,
        primaryContainer: AuraColors.heartbeat.withValues(alpha: 0.2),
        onPrimaryContainer: AuraColors.heartbeat,
        secondary: AuraColors.tether,
        onSecondary: Colors.white,
        secondaryContainer: AuraColors.tether.withValues(alpha: 0.2),
        onSecondaryContainer: AuraColors.tether,
        tertiary: AuraColors.halo,
        onTertiary: Colors.black,
        tertiaryContainer: AuraColors.halo.withValues(alpha: 0.2),
        onTertiaryContainer: AuraColors.halo,
        error: const Color(0xFFFF2E51),
        onError: Colors.white,
        surface: auraColors.bgSecondary,
        onSurface: auraColors.textPrimary,
        surfaceContainerHighest: auraColors.bgSecondary,
        onSurfaceVariant: auraColors.textSecondary,
        outline: auraColors.glassBorder,
        outlineVariant: auraColors.glassBorder.withValues(alpha: 0.5),
        shadow: auraColors.glassShadow,
        scrim: Colors.black.withValues(alpha: 0.5),
        inverseSurface: isDark ? auraColors.textPrimary : auraColors.bgPrimary,
        onInverseSurface: isDark ? auraColors.bgPrimary : auraColors.textPrimary,
        inversePrimary: AuraColors.heartbeat.withValues(alpha: 0.8),
      ),

      // Apply the Trinity of Seduction typography
      textTheme: AuraTypography.getTheme(auraColors),

      // App Bar styling
      appBarTheme: AppBarTheme(
        backgroundColor: auraColors.bgPrimary,
        foregroundColor: auraColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),

      // Card styling with glass physics
      cardTheme: CardThemeData(
        color: auraColors.bgSecondary.withOpacity(auraColors.glassOpacity),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: auraColors.glassBorder, width: 1),
        ),
      ),

      // Elevated Button styling
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AuraColors.heartbeat,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),

      // Text Button styling
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AuraColors.tether,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),

      // Input decoration
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: auraColors.bgSecondary.withOpacity(auraColors.glassOpacity),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: auraColors.glassBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: auraColors.glassBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AuraColors.halo, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),

      // Divider styling
      dividerTheme: DividerThemeData(
        color: auraColors.glassBorder,
        thickness: 1,
      ),

      // Icon styling
      iconTheme: IconThemeData(
        color: auraColors.textPrimary,
        size: 24,
      ),

      // Floating Action Button
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AuraColors.heartbeat,
        foregroundColor: Colors.white,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }

  /// Light theme accessor
  static ThemeData get light => define(Brightness.light);

  /// Dark theme accessor
  static ThemeData get dark => define(Brightness.dark);
}
