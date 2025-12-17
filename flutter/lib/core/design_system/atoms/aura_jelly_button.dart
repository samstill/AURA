/// Project Aura - Jelly Button
/// ============================
/// Icon button with exact CSS keyframe-based "jelly" wobble animation.
/// 
/// Replicates the CSS @keyframes jelly:
/// - 0%: scale(1, 1)
/// - 30%: scale(1.15, 0.85)
/// - 40%: scale(0.92, 1.08)
/// - 50%: scale(1.04, 0.96)
/// - 65%: scale(0.98, 1.02)
/// - 75%: scale(1.01, 0.99)
/// - 100%: scale(1, 1)

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/aura_colors.dart';

class AuraJellyButton extends StatefulWidget {
  final Widget icon;
  final VoidCallback onTap;
  final String? tooltip;
  final bool active;

  const AuraJellyButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.active = false,
  });

  @override
  State<AuraJellyButton> createState() => _AuraJellyButtonState();
}

class _AuraJellyButtonState extends State<AuraJellyButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    // The CSS animation is 0.9s total
    _controller = AnimationController(vsync: this, duration: 900.ms);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    HapticFeedback.lightImpact();
    // Reset and play the keyframe sequence
    _controller.forward(from: 0);
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final aura = context.aura;

    Widget button = GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: _handleTap,
      child: AnimatedScale(
        // CSS: active { transform: scale(0.92); }
        scale: _isPressed ? 0.92 : 1.0,
        duration: 100.ms,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: widget.active
                ? AuraColors.heartbeat.withOpacity(0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: widget.active
                  ? AuraColors.heartbeat.withOpacity(0.3)
                  : Colors.transparent,
            ),
          ),
          child: widget.icon,
        )
            .animate(controller: _controller, autoPlay: false)
            // CSS Keyframe Translation using scale with Offset
            // 0% -> 1.0, 1.0 to 30% -> 1.15, 0.85
            .scale(
              begin: const Offset(1.0, 1.0),
              end: const Offset(1.15, 0.85),
              duration: 270.ms,
              curve: Curves.easeOut,
            )
            .then()
            // 30% -> 40%: 1.15, 0.85 -> 0.92, 1.08
            .scale(
              begin: const Offset(1.15, 0.85),
              end: const Offset(0.92, 1.08),
              duration: 90.ms,
            )
            .then()
            // 40% -> 50%: 0.92, 1.08 -> 1.04, 0.96
            .scale(
              begin: const Offset(0.92, 1.08),
              end: const Offset(1.04, 0.96),
              duration: 90.ms,
            )
            .then()
            // 50% -> 65%: 1.04, 0.96 -> 0.98, 1.02
            .scale(
              begin: const Offset(1.04, 0.96),
              end: const Offset(0.98, 1.02),
              duration: 135.ms,
            )
            .then()
            // 65% -> 75%: 0.98, 1.02 -> 1.01, 0.99
            .scale(
              begin: const Offset(0.98, 1.02),
              end: const Offset(1.01, 0.99),
              duration: 90.ms,
            )
            .then()
            // 75% -> 100%: 1.01, 0.99 -> 1.0, 1.0
            .scale(
              begin: const Offset(1.01, 0.99),
              end: const Offset(1.0, 1.0),
              duration: 225.ms,
            ),
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
