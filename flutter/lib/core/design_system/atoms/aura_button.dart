/// Project Aura - Tension & Sacrifice Button
/// ==========================================
/// Implements the specific motion physics for high-value interactions.
/// Now uses the modular motion system for animations and haptics.
///
/// Phase 1: Tension (Press)
/// - Element sinks deep (scale 0.96)
/// - Shadow disappears
/// - Haptic feedback (light)
///
/// Phase 2: Sacrifice (Release)
/// - Energy explodes outward
/// - Shimmer ripple effect
/// - Haptic feedback (medium)

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/aura_colors.dart';
import '../motion/aura_haptics.dart';
import '../motion/aura_motion.dart';

enum AuraButtonVariant {
  /// Primary action - uses Heartbeat color (Love/Action)
  heartbeat,

  /// Secondary action - uses Tether color (Trust/Structure)
  tether,

  /// Tertiary action - uses Halo color (Intelligence/Guide)
  halo,

  /// Ghost variant - transparent with border
  ghost,
}

class AuraButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final AuraButtonVariant variant;
  final IconData? icon;
  final bool isLoading;
  final bool fullWidth;

  const AuraButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AuraButtonVariant.heartbeat,
    this.icon,
    this.isLoading = false,
    this.fullWidth = false,
  });

  /// Convenience constructor for primary heartbeat button
  const AuraButton.heartbeat({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.fullWidth = false,
  }) : variant = AuraButtonVariant.heartbeat;

  /// Convenience constructor for secondary tether button
  const AuraButton.tether({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.fullWidth = false,
  }) : variant = AuraButtonVariant.tether;

  /// Convenience constructor for ghost button
  const AuraButton.ghost({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.fullWidth = false,
  }) : variant = AuraButtonVariant.ghost;

  @override
  State<AuraButton> createState() => _AuraButtonState();
}

class _AuraButtonState extends State<AuraButton> {
  bool _isPressed = false;

  bool get _isEnabled => widget.onPressed != null && !widget.isLoading;

  Color get _baseColor {
    switch (widget.variant) {
      case AuraButtonVariant.heartbeat:
        return AuraColors.heartbeat;
      case AuraButtonVariant.tether:
        return AuraColors.tether;
      case AuraButtonVariant.halo:
        return AuraColors.halo;
      case AuraButtonVariant.ghost:
        return Colors.transparent;
    }
  }

  Color get _textColor {
    if (widget.variant == AuraButtonVariant.ghost) {
      return context.aura.textPrimary;
    }
    if (widget.variant == AuraButtonVariant.halo) {
      return Colors.black;
    }
    return Colors.white;
  }

  void _handleTapDown(TapDownDetails details) {
    if (!_isEnabled) return;
    setState(() => _isPressed = true);
    AuraHaptics.tension();
  }

  void _handleTapUp(TapUpDetails details) {
    if (!_isEnabled) return;
    setState(() => _isPressed = false);
    AuraHaptics.sacrifice();
    widget.onPressed?.call();
  }

  void _handleTapCancel() {
    setState(() => _isPressed = false);
  }

  @override
  Widget build(BuildContext context) {
    final aura = context.aura;
    final isGhost = widget.variant == AuraButtonVariant.ghost;

    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: AnimatedScale(
        // Phase 1: Tension - Sink Deep
        scale: _isPressed
            ? AuraMotion.tension.pressScale
            : AuraMotion.tension.normalScale,
        duration: AuraMotion.tension.pressDuration,
        curve: AuraMotion.tension.pressCurve,
        child: AnimatedContainer(
          duration: AuraMotion.tension.releaseDuration,
          curve: AuraMotion.tension.releaseCurve,
          width: widget.fullWidth ? double.infinity : null,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
          decoration: BoxDecoration(
            color: _isEnabled
                ? (isGhost ? Colors.transparent : _baseColor)
                : _baseColor.withOpacity(0.5),
            borderRadius: BorderRadius.circular(16),
            border: isGhost
                ? Border.all(color: aura.glassBorder, width: 1)
                : null,
            boxShadow: _isPressed || !_isEnabled || isGhost
                ? [] // Shadow disappears under tension or when disabled
                : [
                    BoxShadow(
                      color: _baseColor.withOpacity(0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
          ),
          child: Row(
            mainAxisSize:
                widget.fullWidth ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.isLoading) ...[
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(_textColor),
                  ),
                ),
                const SizedBox(width: 12),
              ] else if (widget.icon != null) ...[
                Icon(widget.icon, size: 18, color: _textColor),
                const SizedBox(width: 12),
              ],
              Text(
                widget.label.toUpperCase(),
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: _textColor,
                      letterSpacing: 1.5,
                    ),
              ),
            ],
          ),
        ),
      )
          // Phase 2: Sacrifice - Shimmer Ripple Effect
          .animate(target: _isPressed ? 0 : 1)
          .shimmer(
            duration: 600.ms,
            color: Colors.white.withOpacity(0.3),
            curve: AuraMotion.sacrificeOut,
          ),
    );
  }
}

/// Icon-only button with Jelly physics for navigation/status elements
class AuraIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final Color? color;
  final double size;
  final String? tooltip;

  const AuraIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.color,
    this.size = 24,
    this.tooltip,
  });

  @override
  State<AuraIconButton> createState() => _AuraIconButtonState();
}

class _AuraIconButtonState extends State<AuraIconButton>
    with SingleTickerProviderStateMixin {
  bool _isPressed = false;

  void _handleTapDown(TapDownDetails details) {
    if (widget.onPressed == null) return;
    setState(() => _isPressed = true);
    AuraHaptics.jelly();
  }

  void _handleTapUp(TapUpDetails details) {
    if (widget.onPressed == null) return;
    setState(() => _isPressed = false);
    widget.onPressed?.call();
  }

  void _handleTapCancel() {
    setState(() => _isPressed = false);
  }

  @override
  Widget build(BuildContext context) {
    final aura = context.aura;
    final iconColor = widget.color ?? aura.textPrimary;

    Widget button = GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: AnimatedScale(
        // Jelly squash effect
        scale: _isPressed
            ? AuraMotion.jelly.pressScale
            : AuraMotion.jelly.normalScale,
        duration: AuraMotion.jelly.pressDuration,
        curve: AuraMotion.jelly.pressCurve,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: aura.bgSecondary.withOpacity(0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: aura.glassBorder),
          ),
          child: Icon(
            widget.icon,
            size: widget.size,
            color: iconColor,
          ),
        ),
      )
          // Jelly wiggle on release
          .animate(target: _isPressed ? 0 : 1)
          .scale(
            begin: Offset(AuraMotion.jelly.pressScale, AuraMotion.jelly.pressScale),
            end: const Offset(1.0, 1.0),
            duration: AuraMotion.jelly.releaseDuration,
            curve: AuraMotion.jelly.releaseCurve,
          ),
    );

    if (widget.tooltip != null) {
      button = Tooltip(
        message: widget.tooltip!,
        child: button,
      );
    }

    return button;
  }
}
