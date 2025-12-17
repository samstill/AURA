/// Project Aura - Haptic Feedback Utilities
/// =========================================
/// Centralized haptic feedback patterns for consistent tactile responses.
/// 
/// Usage:
/// ```dart
/// AuraHaptics.light();    // Light tap feedback
/// AuraHaptics.medium();   // Confirm action
/// AuraHaptics.heavy();    // Important action
/// AuraHaptics.selection(); // Selection change
/// ```

import 'package:flutter/services.dart';

/// Centralized haptic feedback patterns
class AuraHaptics {
  AuraHaptics._();

  /// Light impact - for initial touches, hover states
  static void light() => HapticFeedback.lightImpact();

  /// Medium impact - for confirmed actions, releases
  static void medium() => HapticFeedback.mediumImpact();

  /// Heavy impact - for important or destructive actions
  static void heavy() => HapticFeedback.heavyImpact();

  /// Selection click - for toggles, radio buttons, list selections
  static void selection() => HapticFeedback.selectionClick();

  /// Vibrate - general vibration pattern
  static void vibrate() => HapticFeedback.vibrate();

  /// Tension pattern - light on press
  static void tension() => lightImpact();

  /// Sacrifice pattern - medium on release
  static void sacrifice() => mediumImpact();

  /// Jelly pattern - selection on press
  static void jelly() => selectionClick();

  // Aliases for semantic naming
  static void lightImpact() => HapticFeedback.lightImpact();
  static void mediumImpact() => HapticFeedback.mediumImpact();
  static void heavyImpact() => HapticFeedback.heavyImpact();
  static void selectionClick() => HapticFeedback.selectionClick();
}
