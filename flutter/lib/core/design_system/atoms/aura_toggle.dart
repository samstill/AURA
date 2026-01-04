/// Project Aura - Liquid Morph Toggle
/// ===================================
/// Toggle switch with "Conservation of Mass" physics.
/// 
/// The thumb stretches wide when moving and snaps back to a circle
/// when it settles - like mercury or honey sliding across the track.
///
/// Physics:
/// - State Change: Thumb stretches wider (24 -> 36)
/// - Movement: Slides to other side with overshoot curve
/// - Settling: Snaps back to circle
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../theme/aura_colors.dart';
import '../motion/aura_motion.dart';

class AuraToggle extends StatefulWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool showIcons;

  const AuraToggle({
    super.key,
    required this.value,
    required this.onChanged,
    this.showIcons = true,
  });

  @override
  State<AuraToggle> createState() => _AuraToggleState();
}

class _AuraToggleState extends State<AuraToggle> {
  bool _isMorphing = false;

  void _handleTap() async {
    HapticFeedback.lightImpact();

    // 1. Start Morph (Stretch)
    setState(() => _isMorphing = true);

    // 2. Trigger Value Change (Slide)
    widget.onChanged(!widget.value);

    // 3. End Morph (Snap back to circle) after slide completes
    await Future.delayed(AuraMotion.standard); // Was: 300ms
    if (mounted) setState(() => _isMorphing = false);
  }

  @override
  Widget build(BuildContext context) {
    final aura = context.aura;

    // Dimensions
    const trackWidth = 64.0;
    const trackHeight = 36.0;
    const thumbSize = 28.0;
    const padding = 4.0;
    const stretchAmount = 12.0;

    return GestureDetector(
      onTap: _handleTap,
      child: AnimatedContainer(
        duration: AuraMotion.standard, // Was: 300ms
        width: trackWidth,
        height: trackHeight,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(99),
          color: widget.value
              ? aura.bgSecondary.withValues(alpha: 0.5)
              : aura.bgSecondary.withValues(alpha: 0.3),
          border: Border.all(
            color: widget.value
                ? AuraColors.tether.withValues(alpha: 0.3)
                : aura.glassBorder,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            AnimatedPositioned(
              duration: AuraMotion.deliberate, // Was: 400ms
              // CSS Curve: cubic-bezier(0.34, 1.56, 0.64, 1) -> Overshoot
              curve: const Cubic(0.34, 1.56, 0.64, 1.0),
              left: widget.value
                  ? trackWidth -
                      thumbSize -
                      padding -
                      (_isMorphing ? stretchAmount / 2 : 0)
                  : padding,
              top: padding,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: AuraMotion.easeOut, // Was: Curves.easeInOut
                height: thumbSize,
                // Liquid Physics: Stretch width when moving
                width: _isMorphing ? thumbSize + stretchAmount : thumbSize,
                decoration: BoxDecoration(
                  color: widget.value ? AuraColors.tether : aura.textPrimary,
                  borderRadius: BorderRadius.circular(99),
                  boxShadow: [
                    BoxShadow(
                      color: widget.value
                          ? AuraColors.tether.withValues(alpha: 0.3)
                          : Colors.black.withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                // Icon Logic (Sun/Moon)
                child: widget.showIcons
                    ? Center(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: Icon(
                            widget.value ? LucideIcons.moon : LucideIcons.sun,
                            key: ValueKey(widget.value),
                            size: 16,
                            color:
                                widget.value ? Colors.white : aura.bgPrimary,
                          ),
                        ),
                      )
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A simplified toggle without the theme icons
class AuraSwitch extends StatefulWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color? activeColor;

  const AuraSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.activeColor,
  });

  @override
  State<AuraSwitch> createState() => _AuraSwitchState();
}

class _AuraSwitchState extends State<AuraSwitch> {
  bool _isMorphing = false;

  void _handleTap() async {
    HapticFeedback.lightImpact();
    setState(() => _isMorphing = true);
    widget.onChanged(!widget.value);
    await Future.delayed(AuraMotion.standard); // Was: 300ms
    if (mounted) setState(() => _isMorphing = false);
  }

  @override
  Widget build(BuildContext context) {
    final aura = context.aura;
    final activeColor = widget.activeColor ?? AuraColors.heartbeat;

    const trackWidth = 52.0;
    const trackHeight = 28.0;
    const thumbSize = 22.0;
    const padding = 3.0;
    const stretchAmount = 8.0;

    return GestureDetector(
      onTap: _handleTap,
      child: AnimatedContainer(
        duration: AuraMotion.standard, // Was: 300ms
        width: trackWidth,
        height: trackHeight,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(99),
          color: widget.value
              ? activeColor.withValues(alpha: 0.3)
              : aura.bgSecondary.withValues(alpha: 0.3),
          border: Border.all(
            color: widget.value
                ? activeColor.withValues(alpha: 0.5)
                : aura.glassBorder,
          ),
        ),
        child: Stack(
          children: [
            AnimatedPositioned(
              duration: AuraMotion.deliberate, // Was: 400ms
              curve: const Cubic(0.34, 1.56, 0.64, 1.0),
              left: widget.value
                  ? trackWidth -
                      thumbSize -
                      padding -
                      (_isMorphing ? stretchAmount / 2 : 0)
                  : padding,
              top: padding,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                height: thumbSize,
                width: _isMorphing ? thumbSize + stretchAmount : thumbSize,
                decoration: BoxDecoration(
                  color: widget.value ? activeColor : aura.textPrimary,
                  borderRadius: BorderRadius.circular(99),
                  boxShadow: [
                    BoxShadow(
                      color: widget.value
                          ? activeColor.withValues(alpha: 0.4)
                          : Colors.black.withValues(alpha: 0.2),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
