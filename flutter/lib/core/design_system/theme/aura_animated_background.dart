/// Project Aura - Animated Background
/// ===================================
/// Reusable animated background with floating orbs and gradient.
/// Used in login screen, splash screen, and other premium screens.

import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/aura_colors.dart';

/// Orb background with floating orbs and gradient
class AuraOrbBackground extends StatefulWidget {
  final Widget child;
  final bool showBottomAccent;
  
  const AuraOrbBackground({
    super.key,
    required this.child,
    this.showBottomAccent = true,
  });

  @override
  State<AuraOrbBackground> createState() => _AuraOrbBackgroundState();
}

class _AuraOrbBackgroundState extends State<AuraOrbBackground>
    with TickerProviderStateMixin {
  late AnimationController _orbController1;
  late AnimationController _orbController2;
  late AnimationController _orbController3;

  @override
  void initState() {
    super.initState();

    // Initialize orb animations with different durations for organic movement
    _orbController1 = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);

    _orbController2 = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat(reverse: true);

    _orbController3 = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _orbController1.dispose();
    _orbController2.dispose();
    _orbController3.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final aura = context.aura;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Gradient Background
          _buildGradientBackground(isDark, aura),

          // Floating Orbs
          _buildFloatingOrbs(isDark),

          // Main Content
          widget.child,

          // Bottom Accent Line
          if (widget.showBottomAccent)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildBottomAccent(isDark),
            ),
        ],
      ),
    );
  }

  Widget _buildGradientBackground(bool isDark, AuraColors aura) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 800),
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0, -0.5),
          radius: 1.5,
          colors: isDark
              ? [
                  const Color(0xFF121212),
                  const Color(0xFF080808),
                  aura.bgPrimary,
                ]
              : [
                  const Color(0xFFFFF5F7),
                  const Color(0xFFFFF9F5),
                  aura.bgPrimary,
                ],
          stops: isDark ? const [0.0, 0.4, 1.0] : const [0.0, 0.3, 1.0],
        ),
      ),
    );
  }

  Widget _buildFloatingOrbs(bool isDark) {
    return Stack(
      children: [
        // Purple/Tether orb - top left with curved motion
        AnimatedBuilder(
          animation: _orbController1,
          builder: (context, child) {
            // Use curved animation for smooth organic movement
            final curvedValue = Curves.easeInOut.transform(_orbController1.value);
            final sinValue = sin(curvedValue * pi * 2) * 0.5 + 0.5;
            
            return Positioned(
              top: MediaQuery.of(context).size.height * 0.1 +
                  (curvedValue * 50) + (sinValue * 20),
              left: MediaQuery.of(context).size.width * 0.05 +
                  (sinValue * 40),
              child: Transform.scale(
                scale: 1.0 + (curvedValue * 0.15),
                child: _FloatingOrb(
                  color: AuraColors.tether,
                  size: 350,
                  opacity: (isDark ? 0.2 : 0.35) + (sinValue * 0.05),
                  blurRadius: 100,
                ),
              ),
            );
          },
        ),

        // Pink/Heartbeat orb - bottom right with pulsing motion
        AnimatedBuilder(
          animation: _orbController2,
          builder: (context, child) {
            final curvedValue = Curves.easeInOut.transform(_orbController2.value);
            final cosValue = cos(curvedValue * pi * 2) * 0.5 + 0.5;
            
            return Positioned(
              bottom: MediaQuery.of(context).size.height * 0.1 +
                  (curvedValue * 60) + (cosValue * 25),
              right: MediaQuery.of(context).size.width * 0.05 +
                  (cosValue * 50),
              child: Transform.scale(
                scale: 1.0 + (cosValue * 0.2),
                child: _FloatingOrb(
                  color: AuraColors.heartbeat,
                  size: 300,
                  opacity: (isDark ? 0.18 : 0.32) + (curvedValue * 0.05),
                  blurRadius: 90,
                ),
              ),
            );
          },
        ),

        // Cyan/Halo orb - center right with floating motion
        AnimatedBuilder(
          animation: _orbController3,
          builder: (context, child) {
            final curvedValue = Curves.easeInOut.transform(_orbController3.value);
            final sinValue = sin(curvedValue * pi * 2) * 0.5 + 0.5;
            
            return Positioned(
              top: MediaQuery.of(context).size.height * 0.35 +
                  (sinValue * 80),
              right: MediaQuery.of(context).size.width * 0.15 +
                  (curvedValue * 60),
              child: Transform.scale(
                scale: 1.0 + (sinValue * 0.1),
                child: _FloatingOrb(
                  color: AuraColors.halo,
                  size: 250,
                  opacity: (isDark ? 0.12 : 0.28) + (curvedValue * 0.03),
                  blurRadius: 80,
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildBottomAccent(bool isDark) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 800),
      opacity: isDark ? 0.3 : 0.25,
      child: Container(
        height: 2,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.transparent,
              AuraColors.tether,
              AuraColors.heartbeat,
              AuraColors.halo,
              Colors.transparent,
            ],
            stops: [0.0, 0.25, 0.5, 0.75, 1.0],
          ),
        ),
      ),
    );
  }
}

/// Floating orb widget for background depth
class _FloatingOrb extends StatelessWidget {
  final Color color;
  final double size;
  final double opacity;
  final double blurRadius;

  const _FloatingOrb({
    required this.color,
    required this.size,
    required this.opacity,
    required this.blurRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withOpacity(opacity),
            color.withOpacity(0),
          ],
          stops: const [0.0, 0.7],
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(opacity * 0.5),
            blurRadius: blurRadius,
            spreadRadius: size * 0.1,
          ),
        ],
      ),
    );
  }
}
