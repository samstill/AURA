/// Project Aura - Background Atmospheres
/// ======================================
/// Implements the atmospheric backgrounds from the design manifest:
/// 
/// - The Void (Dark): Faint charcoal spotlight fading into nothingness
/// - The Mirage (Light): Subtle blush gradient
///
/// Usage:
/// ```dart
/// AuraBackground(
///   child: Scaffold(...),
/// )
/// ```
library;

import 'package:flutter/material.dart';
import 'aura_colors.dart';

/// A background widget that applies the atmospheric gradient
/// based on the current theme (Void or Mirage).
class AuraBackground extends StatelessWidget {
  final Widget child;

  /// Optional override for the gradient alignment
  final Alignment? gradientCenter;

  /// Whether to use the scaffold background or a gradient
  final bool useGradient;

  const AuraBackground({
    super.key,
    required this.child,
    this.gradientCenter,
    this.useGradient = true,
  });

  @override
  Widget build(BuildContext context) {
    final aura = context.aura;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (!useGradient) {
      return Container(
        color: aura.bgPrimary,
        child: child,
      );
    }

    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: gradientCenter ?? const Alignment(0, -0.5),
          radius: 1.2,
          colors: isDark
              ? [
                  // The Void: Faint charcoal spotlight
                  const Color(0xFF121212),
                  const Color(0xFF080808),
                  aura.bgPrimary, // #000000
                ]
              : [
                  // The Mirage: Subtle blush gradient
                  const Color(0xFFFFF5F7),
                  const Color(0xFFFFF9F5),
                  aura.bgPrimary, // #FFF9F5
                ],
          stops: isDark
              ? const [0.0, 0.4, 1.0]
              : const [0.0, 0.3, 1.0],
        ),
      ),
      child: child,
    );
  }
}

/// A scaffold wrapper that automatically applies the Aura background
class AuraScaffold extends StatelessWidget {
  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final Widget? bottomNavigationBar;
  final Widget? drawer;
  final Widget? endDrawer;
  final bool extendBody;
  final bool extendBodyBehindAppBar;
  final bool useGradient;

  const AuraScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.bottomNavigationBar,
    this.drawer,
    this.endDrawer,
    this.extendBody = false,
    this.extendBodyBehindAppBar = false,
    this.useGradient = true,
  });

  @override
  Widget build(BuildContext context) {
    return AuraBackground(
      useGradient: useGradient,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: appBar,
        body: body,
        floatingActionButton: floatingActionButton,
        floatingActionButtonLocation: floatingActionButtonLocation,
        bottomNavigationBar: bottomNavigationBar,
        drawer: drawer,
        endDrawer: endDrawer,
        extendBody: extendBody,
        extendBodyBehindAppBar: extendBodyBehindAppBar,
      ),
    );
  }
}

/// Animated background that smoothly transitions between themes
class AuraAnimatedBackground extends StatelessWidget {
  final Widget child;
  final Duration duration;

  const AuraAnimatedBackground({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 800),
  });

  @override
  Widget build(BuildContext context) {
    final aura = context.aura;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedContainer(
      duration: duration,
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0, -0.5),
          radius: 1.2,
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
          stops: isDark
              ? const [0.0, 0.4, 1.0]
              : const [0.0, 0.3, 1.0],
        ),
      ),
      child: child,
    );
  }
}
