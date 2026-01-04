/// Project Aura - Animation Extensions
/// ====================================
/// Extension methods on Widget and AnimationController for
/// applying Aura motion physics easily.
///
/// Usage:
/// ```dart
/// // On any widget
/// myWidget.withTension(onPressed: () {})
/// myWidget.withJelly(onPressed: () {})
/// myWidget.withIce()  // Slow fade in
/// ```
library;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'aura_motion.dart';
import 'aura_pressable.dart';

/// Extension methods for adding Aura animations to any widget
extension AuraAnimationExtensions on Widget {
  /// Wraps the widget with Tension press physics
  /// Use for: CTAs, cards, important interactive elements
  Widget withTension({
    VoidCallback? onPressed,
    VoidCallback? onLongPress,
    bool enableHaptics = true,
    bool enableShimmer = true,
  }) {
    return AuraPressable.tension(
      onPressed: onPressed,
      onLongPress: onLongPress,
      enableHaptics: enableHaptics,
      enableShimmer: enableShimmer,
      child: this,
    );
  }

  /// Wraps the widget with Jelly press physics
  /// Use for: Icons, toggles, playful elements
  Widget withJelly({
    VoidCallback? onPressed,
    VoidCallback? onLongPress,
    bool enableHaptics = true,
  }) {
    return AuraPressable.jelly(
      onPressed: onPressed,
      onLongPress: onLongPress,
      enableHaptics: enableHaptics,
      child: this,
    );
  }

  /// Wraps the widget with subtle press physics
  /// Use for: Secondary actions, list items
  Widget withSubtlePress({
    VoidCallback? onPressed,
    VoidCallback? onLongPress,
    bool enableHaptics = true,
  }) {
    return AuraPressable.subtle(
      onPressed: onPressed,
      onLongPress: onLongPress,
      enableHaptics: enableHaptics,
      child: this,
    );
  }

  /// Applies "The Ice" animation - slow drift entrance
  /// Elements never stop instantly, they drift to a halt
  Widget withIce({
    Duration? delay,
    Duration? duration,
  }) {
    return animate(delay: delay)
        .fadeIn(
          duration: duration ?? AuraMotion.ice,
          curve: AuraMotion.iceEase,
        )
        .slideY(
          begin: 0.05,
          end: 0,
          duration: duration ?? AuraMotion.ice,
          curve: AuraMotion.iceEase,
        );
  }

  /// Applies a staggered entrance animation
  /// Use for: Lists, grids, sequential reveals
  Widget withStaggeredEntrance({
    required int index,
    Duration staggerDelay = const Duration(milliseconds: 50),
    Duration? duration,
  }) {
    return animate(delay: staggerDelay * index)
        .fadeIn(
          duration: duration ?? AuraMotion.deliberate,
          curve: AuraMotion.easeOut,
        )
        .slideY(
          begin: 0.1,
          end: 0,
          duration: duration ?? AuraMotion.deliberate,
          curve: AuraMotion.iceEase,
        );
  }

  /// Applies a scale entrance animation
  Widget withScaleEntrance({
    Duration? delay,
    Duration? duration,
    double beginScale = 0.95,
  }) {
    return animate(delay: delay)
        .fadeIn(
          duration: duration ?? AuraMotion.standard,
          curve: AuraMotion.easeOut,
        )
        .scale(
          begin: Offset(beginScale, beginScale),
          end: const Offset(1.0, 1.0),
          duration: duration ?? AuraMotion.standard,
          curve: AuraMotion.spring,
        );
  }

  /// Applies a blur entrance animation
  Widget withBlurEntrance({
    Duration? delay,
    Duration? duration,
    double beginBlur = 10.0,
  }) {
    return animate(delay: delay)
        .fadeIn(
          duration: duration ?? AuraMotion.deliberate,
          curve: AuraMotion.easeOut,
        )
        .blur(
          begin: Offset(beginBlur, beginBlur),
          end: Offset.zero,
          duration: duration ?? AuraMotion.deliberate,
          curve: AuraMotion.easeOut,
        );
  }

  /// Applies a shimmer loading effect
  Widget withShimmer({
    Duration? duration,
    Color? color,
  }) {
    return animate(onPlay: (controller) => controller.repeat())
        .shimmer(
          duration: duration ?? const Duration(milliseconds: 1500),
          color: color ?? Colors.white.withValues(alpha: 0.3),
        );
  }

  /// Applies a pulse effect for attention
  Widget withPulse({
    Duration? duration,
    double minScale = 0.97,
    double maxScale = 1.03,
  }) {
    return animate(onPlay: (controller) => controller.repeat(reverse: true))
        .scale(
          begin: Offset(minScale, minScale),
          end: Offset(maxScale, maxScale),
          duration: duration ?? const Duration(milliseconds: 1000),
          curve: Curves.easeInOut,
        );
  }

  /// Applies a breathing glow effect
  Widget withBreathingGlow({
    required Color color,
    Duration? duration,
    double minOpacity = 0.3,
    double maxOpacity = 0.8,
  }) {
    return animate(onPlay: (controller) => controller.repeat(reverse: true))
        .custom(
          duration: duration ?? const Duration(milliseconds: 2000),
          curve: Curves.easeInOut,
          builder: (context, value, child) => Container(
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(
                    minOpacity + (maxOpacity - minOpacity) * value,
                  ),
                  blurRadius: 20 + (10 * value),
                  spreadRadius: -5 + (5 * value),
                ),
              ],
            ),
            child: child,
          ),
        );
  }
}
