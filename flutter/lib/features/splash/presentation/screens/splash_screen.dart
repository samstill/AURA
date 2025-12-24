/// Project Aura - Splash Screen
/// =============================
/// Animated splash screen with SVGator logo and "Encresa Aura" text.
/// Uses the reusable AuraAnimatedBackground component.

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/design_system/design_system.dart';

class SplashScreen extends StatefulWidget {
  final VoidCallback? onComplete;
  final Duration duration;

  const SplashScreen({
    super.key,
    this.onComplete,
    this.duration = const Duration(seconds: 4),
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _textController;

  @override
  void initState() {
    super.initState();
    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    // Start text animation after a delay
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        _textController.forward();
      }
    });

    // Complete splash after duration
    Future.delayed(widget.duration, () {
      if (mounted && widget.onComplete != null) {
        widget.onComplete!();
      }
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return AuraOrbBackground(
      showBottomAccent: true,
      child: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated Logo
              const SplashScreenIcon(
                width: 200,
                height: 200,
              )
                  .animate()
                  .fadeIn(duration: 600.ms)
                  .scale(
                    begin: const Offset(0.8, 0.8),
                    end: const Offset(1.0, 1.0),
                    duration: 800.ms,
                    curve: Curves.easeOutBack,
                  ),

              const SizedBox(height: 32),

              // Animated "Encresa Aura" text
              AnimatedBuilder(
                animation: _textController,
                builder: (context, child) {
                  return Opacity(
                    opacity: _textController.value,
                    child: Transform.translate(
                      offset: Offset(0, 20 * (1 - _textController.value)),
                      child: child,
                    ),
                  );
                },
                child: Column(
                  children: [
                    // "Encresa" - subtle, elegant
                    Text(
                      'Encresa',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 8,
                        color: isDark
                            ? Colors.white.withOpacity(0.5)
                            : Colors.black.withOpacity(0.4),
                      ),
                    ),
                    const SizedBox(height: 4),
                    // "Aura" - bold, prominent with gradient
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [
                          AuraColors.tether,
                          AuraColors.heartbeat,
                          AuraColors.halo,
                        ],
                      ).createShader(bounds),
                      child: Text(
                        'AURA',
                        style: GoogleFonts.outfit(
                          fontSize: 48,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 12,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
