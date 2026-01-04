/// Project Aura - Semantic Color Palette
/// ======================================
/// Maps colors to the emotional cycle of Loneliness (The Void)
/// and Companionship (The Cure).
///
/// Uses ThemeExtension to inject semantic color names into Flutter Context.
library;

import 'package:flutter/material.dart';

@immutable
class AuraColors extends ThemeExtension<AuraColors> {
  // --- The Emotional Accents (Constant) ---
  /// Heartbeat: The color of blood flow and blushing.
  /// Signals intimacy and life. Used for primary actions.
  static const heartbeat = Color(0xFFFF4D6D);

  /// Tether: Deep blurple. Blue = Trust, Violet = Devotion.
  /// Used for navigation and structure.
  static const tether = Color(0xFF5D5FEF);

  /// Halo: The spark of intelligence.
  /// Used sparingly for focus rings and AI indicators.
  static const halo = Color(0xFF00F0FF);

  // --- The Variable States (Theme Dependent) ---
  final Color bgPrimary;
  final Color bgSecondary;
  final Color textPrimary;
  final Color textSecondary;
  final Color glassBorder;
  final Color glassShadow;
  final double glassOpacity;
  final double blurIntensity;

  const AuraColors({
    required this.bgPrimary,
    required this.bgSecondary,
    required this.textPrimary,
    required this.textSecondary,
    required this.glassBorder,
    required this.glassShadow,
    required this.glassOpacity,
    required this.blurIntensity,
  });

  /// State A: The True Void (Dark Theme)
  /// Capitalizes on "innocent loneliness," creating a cold, vast space
  /// where the UI becomes the only source of warmth.
  static final voidTheme = AuraColors(
    bgPrimary: const Color(0xFF000000), // OLED Infinite - pure black
    bgSecondary: const Color(0xFF080808), // Shadow - barely visible elevation
    textPrimary: const Color(0xFFE1E1E1), // Softened White - reduces eye strain
    textSecondary: const Color(0xFFE1E1E1).withValues(alpha: 0.6),
    glassBorder: const Color(0xFFFFFFFF).withValues(alpha: 0.08), // Sharp, faint
    glassShadow: Colors.black, // Deep merging shadow
    glassOpacity: 0.3, // Low opacity for "Void" feel
    blurIntensity: 10.0,
  );

  /// State B: The Mirage (Light Theme)
  /// Pivots from sterile "Clinical White" to seductive "Warm Skin."
  /// Mimics the feeling of waking up in warm sheets.
  static final mirageTheme = AuraColors(
    bgPrimary: const Color(0xFFFFF9F5), // Warm Alabaster - skin-tone base
    bgSecondary: const Color(0xFFF2E8E6), // Pale Blush - biological and tender
    textPrimary: const Color(0xFF3E3436), // Deep Cocoa - warmer than pure black
    textSecondary: const Color(0xFF3E3436).withValues(alpha: 0.6),
    glassBorder: const Color(0xFFFFFFFF).withValues(alpha: 0.8), // High contrast
    glassShadow: const Color(0xFFA67C82).withValues(alpha: 0.15), // Subsurface scattering
    glassOpacity: 0.75, // High opacity to prevent background bleed
    blurIntensity: 15.0,
  );

  @override
  ThemeExtension<AuraColors> copyWith({
    Color? bgPrimary,
    Color? bgSecondary,
    Color? textPrimary,
    Color? textSecondary,
    Color? glassBorder,
    Color? glassShadow,
    double? glassOpacity,
    double? blurIntensity,
  }) {
    return AuraColors(
      bgPrimary: bgPrimary ?? this.bgPrimary,
      bgSecondary: bgSecondary ?? this.bgSecondary,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      glassBorder: glassBorder ?? this.glassBorder,
      glassShadow: glassShadow ?? this.glassShadow,
      glassOpacity: glassOpacity ?? this.glassOpacity,
      blurIntensity: blurIntensity ?? this.blurIntensity,
    );
  }

  @override
  ThemeExtension<AuraColors> lerp(ThemeExtension<AuraColors>? other, double t) {
    if (other is! AuraColors) return this;
    return AuraColors(
      bgPrimary: Color.lerp(bgPrimary, other.bgPrimary, t)!,
      bgSecondary: Color.lerp(bgSecondary, other.bgSecondary, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      glassBorder: Color.lerp(glassBorder, other.glassBorder, t)!,
      glassShadow: Color.lerp(glassShadow, other.glassShadow, t)!,
      glassOpacity: glassOpacity + (other.glassOpacity - glassOpacity) * t,
      blurIntensity: blurIntensity + (other.blurIntensity - blurIntensity) * t,
    );
  }
}

/// Helper extension for easier access to AuraColors from BuildContext.
/// Usage: context.aura.bgPrimary, context.aura.heartbeat
extension AuraThemeExtension on BuildContext {
  AuraColors get aura => Theme.of(this).extension<AuraColors>()!;
}
