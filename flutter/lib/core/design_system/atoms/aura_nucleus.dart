/// Project Aura - Nucleus Component
/// ==================================
/// The animated "Nucleus" orb - the central voice activation button.
///
/// Features:
/// - Idle State: Gentle 60 BPM pulse animation, glowing ember core
/// - Pressed State: "Inhale" shrink animation, ember dims
/// - Active State: Liquid morphing border-radius, voice-reactive scaling
/// - Voice States: silence → whisper → loud with color/scale changes
library;

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../theme/aura_colors.dart';
import '../motion/aura_motion.dart';

/// Voice activity state for the Nucleus
enum NucleusVoiceState {
  /// No voice input detected
  silence,

  /// Low volume voice input
  whisper,

  /// High volume voice input
  loud,
}

/// The Nucleus - animated orb for voice activation
class AuraNucleus extends StatefulWidget {
  /// Whether the nucleus is currently active (listening)
  final bool isActive;

  /// Current voice state when active
  final NucleusVoiceState voiceState;

  /// Callback when the nucleus is tapped (when inactive = start secretary)
  final VoidCallback? onTap;

  /// Callback when the nucleus is tapped while active (stop/end turn)
  final VoidCallback? onActiveTap;

  /// Callback when the nucleus is short pressed (start secretary voice)
  final VoidCallback? onActivate;

  /// Callback when the nucleus is long pressed (OpenAI Realtime)
  final VoidCallback? onLongPress;

  /// Size of the nucleus
  final double size;

  const AuraNucleus({
    super.key,
    this.isActive = false,
    this.voiceState = NucleusVoiceState.silence,
    this.onTap,
    this.onActiveTap,
    this.onActivate,
    this.onLongPress,
    this.size = 100,
  });

  @override
  State<AuraNucleus> createState() => _AuraNucleusState();
}

class _AuraNucleusState extends State<AuraNucleus>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _morphController;
  late AnimationController _rippleController;

  late Animation<double> _pulseAnimation;
  late Animation<double> _morphAnimation;
  late Animation<double> _rippleAnimation;

  bool _isPressed = false;
  bool _showRipple = false;
  bool _isDisposed = false;

  void _safeSetState(VoidCallback fn) {
    if (_isDisposed || !mounted) return;
    try {
      setState(fn);
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();

    // Idle pulse animation - 60 BPM (1 second per beat)
    _pulseController = AnimationController(
      vsync: this,
      duration: AuraMotion.dramatic, // Was: 1000ms
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.02).animate(
      CurvedAnimation(parent: _pulseController, curve: AuraMotion.easeOut), // Was: Curves.easeInOut
    );

    // Liquid morph animation for active state
    _morphController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _morphAnimation = Tween<double>(begin: 0, end: 2 * pi).animate(
      CurvedAnimation(parent: _morphController, curve: Curves.linear),
    );

    // Ripple animation for activation
    _rippleController = AnimationController(
      vsync: this,
      duration: AuraMotion.ice, // Was: 800ms
    );

    _rippleAnimation = Tween<double>(begin: 1.0, end: 3.0).animate(
      CurvedAnimation(parent: _rippleController, curve: AuraMotion.easeOut), // Was: Curves.easeOut
    );

    _rippleController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _safeSetState(() => _showRipple = false);
        _rippleController.reset();
      }
    });
  }

  @override
  void didUpdateWidget(AuraNucleus oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Trigger ripple on activation
    if (widget.isActive && !oldWidget.isActive) {
      _safeSetState(() => _showRipple = true);
      _rippleController.forward();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _pulseController.dispose();
    _morphController.dispose();
    _rippleController.dispose();
    super.dispose();
  }

  void _handlePressStart() {
    if (widget.isActive || _isDisposed) return;
    _safeSetState(() => _isPressed = true);
    HapticFeedback.lightImpact();
  }

  void _handlePressEnd() {
    if (_isDisposed) return;
    if (_isPressed) {
      _safeSetState(() => _isPressed = false);
      // Short tap when inactive = start secretary voice
      widget.onActivate?.call();
      HapticFeedback.mediumImpact();
    } else if (widget.isActive) {
      // Tap when active = stop/end turn
      widget.onActiveTap?.call();
    }
  }

  void _handleLongPress() {
    if (widget.isActive || _isDisposed) return;
    _safeSetState(() => _isPressed = false);
    // Long press = OpenAI Realtime
    widget.onLongPress?.call();
    HapticFeedback.heavyImpact();
  }

  void _handlePressCancel() {
    if (_isDisposed) return;
    _safeSetState(() => _isPressed = false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      width: widget.size * 3,
      height: widget.size * 3,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Ghost Ring (Ripple) - activation feedback
          if (_showRipple)
            AnimatedBuilder(
              animation: _rippleAnimation,
              builder: (context, child) => Container(
                width: widget.size * _rippleAnimation.value,
                height: widget.size * _rippleAnimation.value,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AuraColors.heartbeat
                        .withOpacity(1 - _rippleController.value),
                    width: 2,
                  ),
                ),
              ),
            ),

          // Halo glow (Dark mode only, idle state)
          if (isDark && !widget.isActive)
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) => Container(
                width: widget.size * 1.6,
                height: widget.size * 1.6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AuraColors.tether.withOpacity(0.2 * _pulseAnimation.value),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.7],
                  ),
                ),
              ),
            ),

          // The Nucleus (Main Button)
          GestureDetector(
            onTapDown: (_) => _handlePressStart(),
            onTapUp: (_) => _handlePressEnd(),
            onTapCancel: _handlePressCancel,
            onLongPress: _handleLongPress,
            child: AnimatedBuilder(
              animation: Listenable.merge([
                _pulseAnimation,
                _morphAnimation,
              ]),
              builder: (context, child) => _buildNucleus(isDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNucleus(bool isDark) {
    // Calculate scale based on state
    double scale;
    if (_isPressed) {
      scale = 0.9; // Inhale
    } else if (widget.isActive) {
      scale = _getActiveScale();
    } else {
      scale = _pulseAnimation.value;
    }

    // Calculate border radius for liquid morph
    final borderRadius = widget.isActive
        ? _getLiquidBorderRadius()
        : BorderRadius.circular(widget.size / 2);

    // Calculate colors based on state
    final backgroundColor = _getBackgroundColor(isDark);
    final shadowColor = _getShadowColor(isDark);

    return Transform.scale(
      scale: scale,
      child: AnimatedContainer(
        duration: AuraMotion.quick,
        curve: AuraMotion.iceEase,
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: borderRadius,
          boxShadow: [
            if (widget.isActive)
              BoxShadow(
                color: shadowColor,
                blurRadius: 30,
                spreadRadius: 5,
              ),
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.5)
                  : const Color(0xFFA67C82).withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.15)
                : Colors.white.withValues(alpha: 0.8),
            width: 1.5,
          ),
        ),
        child: ClipRRect(
          borderRadius: borderRadius,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // The Core (Ember) - Only visible when not active
              if (!widget.isActive) _buildEmber(isDark),

              // Microphone Icon - Appears on hover/focus
              if (!widget.isActive)
                AnimatedOpacity(
                  duration: AuraMotion.quick,
                  opacity: _isPressed ? 0.0 : 0.3,
                  child: Icon(
                    LucideIcons.mic,
                    size: widget.size * 0.32,
                    color: Theme.of(context).extension<AuraColors>()!.textPrimary,
                  ),
                ),

              // Voice ripples when active
              if (widget.isActive && widget.voiceState != NucleusVoiceState.silence)
                _buildVoiceRipples(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmber(bool isDark) {
    final emberOpacity = _isPressed ? 0.2 : 0.8;
    final emberScale = _isPressed ? 0.5 : 0.9 + (_pulseAnimation.value - 1) * 5;

    return AnimatedOpacity(
      duration: AuraMotion.deliberate,
      opacity: emberOpacity,
      child: AnimatedScale(
        duration: AuraMotion.quick,
        scale: emberScale,
        child: Container(
          width: widget.size * 0.4,
          height: widget.size * 0.4,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                AuraColors.heartbeat.withValues(alpha: 0.8),
                Colors.transparent,
              ],
              stops: const [0.0, 0.8],
            ),
            boxShadow: [
              BoxShadow(
                color: AuraColors.heartbeat.withValues(alpha: 0.5),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVoiceRipples() {
    final rippleScale = widget.voiceState == NucleusVoiceState.loud ? 2.5 : 1.5;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 1.0, end: rippleScale),
      duration: const Duration(seconds: 1),
      builder: (context, value, child) => Container(
        width: widget.size * value,
        height: widget.size * value,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withOpacity(0.2 / value),
            width: 1,
          ),
        ),
      ),
    );
  }

  double _getActiveScale() {
    switch (widget.voiceState) {
      case NucleusVoiceState.loud:
        return 1.0 + 0.2 * sin(_morphAnimation.value * 2);
      case NucleusVoiceState.whisper:
        return 1.0 + 0.05 * sin(_morphAnimation.value * 2);
      case NucleusVoiceState.silence:
        return 1.0;
    }
  }

  BorderRadius _getLiquidBorderRadius() {
    final t = _morphAnimation.value;
    final a = 0.5 + 0.1 * sin(t);
    final b = 0.5 + 0.1 * cos(t);
    final c = 0.5 + 0.1 * sin(t + pi / 2);
    final d = 0.5 + 0.1 * cos(t + pi / 2);

    final maxRadius = widget.size / 2;

    return BorderRadius.only(
      topLeft: Radius.circular(maxRadius * a),
      topRight: Radius.circular(maxRadius * b),
      bottomLeft: Radius.circular(maxRadius * c),
      bottomRight: Radius.circular(maxRadius * d),
    );
  }

  Color _getBackgroundColor(bool isDark) {
    if (!widget.isActive) {
      return isDark
          ? Colors.black.withValues(alpha: 0.8)
          : const Color(0xFFFFF5F7).withValues(alpha: 0.9);
    }

    switch (widget.voiceState) {
      case NucleusVoiceState.loud:
        return const Color(0xFFFF1493); // Deep pink
      case NucleusVoiceState.whisper:
        return AuraColors.tether;
      case NucleusVoiceState.silence:
        return isDark ? Colors.black : const Color(0xFFFFF5F7);
    }
  }

  Color _getShadowColor(bool isDark) {
    if (!widget.isActive) return Colors.transparent;

    switch (widget.voiceState) {
      case NucleusVoiceState.loud:
        return const Color(0xFFFF00FF).withValues(alpha: 0.5);
      case NucleusVoiceState.whisper:
        return AuraColors.tether.withValues(alpha: 0.5);
      case NucleusVoiceState.silence:
        return AuraColors.tether.withValues(alpha: 0.3);
    }
  }
}
