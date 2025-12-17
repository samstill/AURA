/// Project Aura - Pressable Wrapper
/// =================================
/// A reusable wrapper that adds physics-based press interactions to any widget.
/// 
/// Supports two animation styles:
/// - **Tension**: Deep sink, no bounce (for CTAs, cards, important actions)
/// - **Jelly**: Squash with bounce back (for icons, toggles, playful elements)
///
/// Usage:
/// ```dart
/// // Tension style (default)
/// AuraPressable(
///   onPressed: () => print("Pressed!"),
///   child: MyCard(),
/// )
///
/// // Jelly style
/// AuraPressable.jelly(
///   onPressed: () => print("Bounced!"),
///   child: MyIcon(),
/// )
/// ```

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'aura_haptics.dart';
import 'aura_motion.dart';

/// Animation style for pressable interactions
enum PressableStyle {
  /// Deep sink, no bounce - for high-value interactions
  tension,
  /// Squash with elastic bounce - for playful interactions
  jelly,
  /// Subtle press - for less prominent elements
  subtle,
}

/// A wrapper that adds physics-based press animations to any child widget
class AuraPressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;
  final PressableStyle style;
  final bool enableHaptics;
  final bool enableShimmer;
  final Duration? customPressDuration;
  final Duration? customReleaseDuration;
  final double? customPressScale;

  const AuraPressable({
    super.key,
    required this.child,
    this.onPressed,
    this.onLongPress,
    this.style = PressableStyle.tension,
    this.enableHaptics = true,
    this.enableShimmer = false,
    this.customPressDuration,
    this.customReleaseDuration,
    this.customPressScale,
  });

  /// Creates a pressable with Tension style (default)
  const AuraPressable.tension({
    super.key,
    required this.child,
    this.onPressed,
    this.onLongPress,
    this.enableHaptics = true,
    this.enableShimmer = true,
    this.customPressDuration,
    this.customReleaseDuration,
    this.customPressScale,
  }) : style = PressableStyle.tension;

  /// Creates a pressable with Jelly style
  const AuraPressable.jelly({
    super.key,
    required this.child,
    this.onPressed,
    this.onLongPress,
    this.enableHaptics = true,
    this.enableShimmer = false,
    this.customPressDuration,
    this.customReleaseDuration,
    this.customPressScale,
  }) : style = PressableStyle.jelly;

  /// Creates a pressable with subtle style
  const AuraPressable.subtle({
    super.key,
    required this.child,
    this.onPressed,
    this.onLongPress,
    this.enableHaptics = true,
    this.enableShimmer = false,
    this.customPressDuration,
    this.customReleaseDuration,
    this.customPressScale,
  }) : style = PressableStyle.subtle;

  @override
  State<AuraPressable> createState() => _AuraPressableState();
}

class _AuraPressableState extends State<AuraPressable> {
  bool _isPressed = false;

  bool get _isEnabled => widget.onPressed != null || widget.onLongPress != null;

  double get _pressScale {
    if (widget.customPressScale != null) return widget.customPressScale!;
    switch (widget.style) {
      case PressableStyle.tension:
        return AuraMotion.tension.pressScale;
      case PressableStyle.jelly:
        return AuraMotion.jelly.pressScale;
      case PressableStyle.subtle:
        return AuraMotion.subtlePress;
    }
  }

  Duration get _pressDuration {
    if (widget.customPressDuration != null) return widget.customPressDuration!;
    switch (widget.style) {
      case PressableStyle.tension:
        return AuraMotion.tension.pressDuration;
      case PressableStyle.jelly:
        return AuraMotion.jelly.pressDuration;
      case PressableStyle.subtle:
        return AuraMotion.quick;
    }
  }

  Duration get _releaseDuration {
    if (widget.customReleaseDuration != null) return widget.customReleaseDuration!;
    switch (widget.style) {
      case PressableStyle.tension:
        return AuraMotion.tension.releaseDuration;
      case PressableStyle.jelly:
        return AuraMotion.jelly.releaseDuration;
      case PressableStyle.subtle:
        return AuraMotion.standard;
    }
  }

  Curve get _pressCurve {
    switch (widget.style) {
      case PressableStyle.tension:
        return AuraMotion.tension.pressCurve;
      case PressableStyle.jelly:
        return AuraMotion.jelly.pressCurve;
      case PressableStyle.subtle:
        return AuraMotion.easeOut;
    }
  }

  Curve get _releaseCurve {
    switch (widget.style) {
      case PressableStyle.tension:
        return AuraMotion.tension.releaseCurve;
      case PressableStyle.jelly:
        return AuraMotion.jelly.releaseCurve;
      case PressableStyle.subtle:
        return AuraMotion.easeOut;
    }
  }

  void _handleTapDown(TapDownDetails details) {
    if (!_isEnabled) return;
    setState(() => _isPressed = true);
    if (widget.enableHaptics) {
      switch (widget.style) {
        case PressableStyle.tension:
          AuraHaptics.tension();
          break;
        case PressableStyle.jelly:
          AuraHaptics.jelly();
          break;
        case PressableStyle.subtle:
          AuraHaptics.light();
          break;
      }
    }
  }

  void _handleTapUp(TapUpDetails details) {
    if (!_isEnabled) return;
    setState(() => _isPressed = false);
    if (widget.enableHaptics) {
      AuraHaptics.sacrifice();
    }
    widget.onPressed?.call();
  }

  void _handleTapCancel() {
    setState(() => _isPressed = false);
  }

  void _handleLongPress() {
    if (widget.enableHaptics) {
      AuraHaptics.heavy();
    }
    widget.onLongPress?.call();
  }

  @override
  Widget build(BuildContext context) {
    Widget child = GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      onLongPress: widget.onLongPress != null ? _handleLongPress : null,
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _isPressed ? _pressScale : AuraMotion.normalScale,
        duration: _isPressed ? _pressDuration : _releaseDuration,
        curve: _isPressed ? _pressCurve : _releaseCurve,
        child: widget.child,
      ),
    );

    // Apply shimmer effect for tension style
    if (widget.enableShimmer && widget.style == PressableStyle.tension) {
      child = child
          .animate(target: _isPressed ? 0 : 1)
          .shimmer(
            duration: 600.ms,
            color: Colors.white.withOpacity(0.3),
            curve: Curves.easeOut,
          );
    }

    // Apply bounce for jelly style
    if (widget.style == PressableStyle.jelly && !_isPressed) {
      child = child
          .animate(target: _isPressed ? 0 : 1)
          .scale(
            begin: Offset(_pressScale, _pressScale),
            end: const Offset(1.0, 1.0),
            duration: _releaseDuration,
            curve: _releaseCurve,
          );
    }

    return child;
  }
}
