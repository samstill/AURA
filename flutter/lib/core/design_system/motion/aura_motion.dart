/// Project Aura - Motion Physics Constants
/// ========================================
/// Centralized animation curves, durations, and physics constants
/// following the "Ice" (Global Momentum) design principle.
library;

import 'package:flutter/animation.dart';

/// Motion physics constants and curves
class AuraMotion {
  AuraMotion._();

  // ============================================
  // DURATIONS
  // ============================================

  /// Instant feedback (50-100ms)
  static const Duration instant = Duration(milliseconds: 80);

  /// Quick response (100-200ms)
  static const Duration quick = Duration(milliseconds: 150);

  /// Standard transitions (200-300ms)
  static const Duration standard = Duration(milliseconds: 250);

  /// Deliberate, noticeable (400-600ms)
  static const Duration deliberate = Duration(milliseconds: 500);

  /// The Ice - slow drift to halt (800-1000ms)
  static const Duration ice = Duration(milliseconds: 800);

  /// Long, dramatic transitions (1000ms+)
  static const Duration dramatic = Duration(milliseconds: 1000);

  // ============================================
  // CURVES
  // ============================================

  /// Standard ease out - for most animations
  static const Curve easeOut = Curves.easeOutCubic;

  /// Heavy ease out - "The Ice" global momentum
  /// Elements drift to a halt, never stopping instantly
  static const Curve iceEase = Cubic(0.23, 1, 0.32, 1);

  /// Elastic out - for "Jelly" bounce effects
  static const Curve jellyBounce = Curves.elasticOut;

  /// Smooth spring - natural feeling responses
  static const Curve spring = Curves.easeOutBack;

  /// Tension curve - sinking feeling
  static const Curve tensionIn = Curves.easeOutCubic;

  /// Sacrifice curve - explosive release
  static const Curve sacrificeOut = Curves.easeOut;

  // ============================================
  // SCALE VALUES
  // ============================================

  /// Tension sink scale (deep press)
  static const double tensionScale = 0.96;

  /// Jelly squash scale (playful press)
  static const double jellySquash = 0.92;

  /// Subtle press scale
  static const double subtlePress = 0.98;

  /// Normal scale
  static const double normalScale = 1.0;

  // ============================================
  // NAMED PRESETS
  // ============================================

  /// Tension animation preset
  static const TensionPreset tension = TensionPreset();

  /// Jelly animation preset
  static const JellyPreset jelly = JellyPreset();

  /// Ice (global momentum) preset
  static const IcePreset iceMotion = IcePreset();
}

/// Preset for Tension animations (high-value interactions)
class TensionPreset {
  const TensionPreset();

  Duration get pressDuration => AuraMotion.quick;
  Duration get releaseDuration => const Duration(milliseconds: 200);
  Curve get pressCurve => AuraMotion.tensionIn;
  Curve get releaseCurve => AuraMotion.sacrificeOut;
  double get pressScale => AuraMotion.tensionScale;
  double get normalScale => AuraMotion.normalScale;
}

/// Preset for Jelly animations (playful interactions)
class JellyPreset {
  const JellyPreset();

  Duration get pressDuration => const Duration(milliseconds: 100);
  Duration get releaseDuration => const Duration(milliseconds: 400);
  Curve get pressCurve => AuraMotion.easeOut;
  Curve get releaseCurve => AuraMotion.jellyBounce;
  double get pressScale => AuraMotion.jellySquash;
  double get normalScale => AuraMotion.normalScale;
}

/// Preset for Ice animations (slow drift)
class IcePreset {
  const IcePreset();

  Duration get duration => AuraMotion.ice;
  Curve get curve => AuraMotion.iceEase;
}
