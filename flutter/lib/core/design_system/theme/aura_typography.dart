/// Project Aura - Typography System
/// =================================
/// The Trinity of Seduction: Fonts that balance biological safety
/// with high-status structure.
///
/// - Outfit (The Inviter): Geometric with "Baby Face" circular dots
/// - Manrope (The Narrator): Neutral and legible
/// - Jura (The Protector): Wide structure with soft terminals

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'aura_colors.dart';

class AuraTypography {
  AuraTypography._();

  /// Generates a complete TextTheme using the Trinity of Seduction fonts.
  static TextTheme getTheme(AuraColors colors) {
    return TextTheme(
      // === The Inviter (Headings) - Outfit ===
      displayLarge: GoogleFonts.outfit(
        fontSize: 57,
        fontWeight: FontWeight.bold,
        color: colors.textPrimary,
        letterSpacing: -1.5,
        height: 1.12,
      ),
      displayMedium: GoogleFonts.outfit(
        fontSize: 45,
        fontWeight: FontWeight.bold,
        color: colors.textPrimary,
        letterSpacing: -1.0,
        height: 1.16,
      ),
      displaySmall: GoogleFonts.outfit(
        fontSize: 36,
        fontWeight: FontWeight.bold,
        color: colors.textPrimary,
        letterSpacing: -0.5,
        height: 1.22,
      ),
      headlineLarge: GoogleFonts.outfit(
        fontSize: 32,
        fontWeight: FontWeight.w600,
        color: colors.textPrimary,
        letterSpacing: -0.5,
        height: 1.25,
      ),
      headlineMedium: GoogleFonts.outfit(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        color: colors.textPrimary,
        letterSpacing: -0.25,
        height: 1.29,
      ),
      headlineSmall: GoogleFonts.outfit(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: colors.textPrimary,
        letterSpacing: 0,
        height: 1.33,
      ),
      titleLarge: GoogleFonts.outfit(
        fontSize: 22,
        fontWeight: FontWeight.w500,
        color: colors.textPrimary,
        letterSpacing: 0,
        height: 1.27,
      ),
      titleMedium: GoogleFonts.outfit(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: colors.textPrimary,
        letterSpacing: 0.15,
        height: 1.5,
      ),
      titleSmall: GoogleFonts.outfit(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: colors.textPrimary,
        letterSpacing: 0.1,
        height: 1.43,
      ),

      // === The Narrator (Body) - Manrope ===
      bodyLarge: GoogleFonts.manrope(
        fontSize: 16,
        fontWeight: FontWeight.normal,
        color: colors.textPrimary,
        letterSpacing: 0.5,
        height: 1.5,
      ),
      bodyMedium: GoogleFonts.manrope(
        fontSize: 14,
        fontWeight: FontWeight.normal,
        color: colors.textPrimary,
        letterSpacing: 0.25,
        height: 1.43,
      ),
      bodySmall: GoogleFonts.manrope(
        fontSize: 12,
        fontWeight: FontWeight.normal,
        color: colors.textSecondary,
        letterSpacing: 0.4,
        height: 1.33,
      ),

      // === The Protector (Data/Buttons) - Jura ===
      labelLarge: GoogleFonts.jura(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: colors.textPrimary,
        letterSpacing: 1.2, // Wide structure for authority
      ),
      labelMedium: GoogleFonts.jura(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: colors.textPrimary,
        letterSpacing: 1.0,
      ),
      labelSmall: GoogleFonts.jura(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: colors.textSecondary,
        letterSpacing: 0.8,
      ),
    );
  }
}
