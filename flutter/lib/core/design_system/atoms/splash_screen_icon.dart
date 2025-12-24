/// Project Aura - Splash Screen Icon
/// ==================================
/// Animated logo for splash screen using flutter_animate.
/// Static SVG with programmatic animations for reliability.

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_svg/flutter_svg.dart';

class SplashScreenIcon extends StatelessWidget {
  final double? width;
  final double? height;

  const SplashScreenIcon({
    super.key,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return SizedBox(
      width: width ?? 200,
      height: height ?? 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Main logo ring
          _buildMainLogo(isDark)
              .animate(onPlay: (c) => c.repeat())
              .shimmer(
                duration: 2000.ms,
                color: Colors.white.withOpacity(0.3),
              ),
          
          // Center eye/gear element
          _buildCenterElement(isDark)
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scale(
                begin: const Offset(0.95, 0.95),
                end: const Offset(1.05, 1.05),
                duration: 1500.ms,
                curve: Curves.easeInOut,
              ),
          
          // Sparkle star
          Positioned(
            top: 30,
            right: 30,
            child: _buildSparkle(isDark)
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .fadeIn(duration: 600.ms)
                .then()
                .fadeOut(duration: 600.ms)
                .scale(
                  begin: const Offset(0.8, 0.8),
                  end: const Offset(1.2, 1.2),
                  duration: 1200.ms,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainLogo(bool isDark) {
    return Container(
      width: 160,
      height: 160,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: isDark ? Colors.white : const Color(0xFF1a1a1a),
          width: 3,
        ),
        boxShadow: [
          BoxShadow(
            color: (isDark ? Colors.white : Colors.black).withOpacity(0.1),
            blurRadius: 30,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Center(
        child: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
            border: Border.all(
              color: isDark ? Colors.white.withOpacity(0.5) : const Color(0xFF1a1a1a).withOpacity(0.5),
              width: 2,
            ),
          ),
          child: Center(
            child: Text(
              'e',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF1a1a1a),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCenterElement(bool isDark) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            (isDark ? Colors.white : const Color(0xFF1a1a1a)).withOpacity(0.3),
            Colors.transparent,
          ],
        ),
      ),
    );
  }

  Widget _buildSparkle(bool isDark) {
    final color = isDark ? Colors.white : const Color(0xFF1a1a1a);
    return SizedBox(
      width: 24,
      height: 24,
      child: CustomPaint(
        painter: _SparklePainter(color: color),
      ),
    );
  }
}

class _SparklePainter extends CustomPainter {
  final Color color;

  _SparklePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2;

    // Draw 4-point star
    final path = Path();
    path.moveTo(cx, 0);
    path.lineTo(cx + r * 0.15, cy - r * 0.15);
    path.lineTo(size.width, cy);
    path.lineTo(cx + r * 0.15, cy + r * 0.15);
    path.lineTo(cx, size.height);
    path.lineTo(cx - r * 0.15, cy + r * 0.15);
    path.lineTo(0, cy);
    path.lineTo(cx - r * 0.15, cy - r * 0.15);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
