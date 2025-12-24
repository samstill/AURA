/// Project Aura - Glass Container
/// ===============================
/// A glassmorphic container that auto-adjusts based on the current theme.
/// 
/// - Void (Dark): Low opacity, sharp borders, deep shadows
/// - Mirage (Light): High opacity, strong borders, warm subsurface shadows

import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/aura_colors.dart';

class AuraGlass extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry padding;
  final BorderRadius? borderRadius;
  final VoidCallback? onTap;
  final bool enableBlur;
  final bool enableGradientBorder;

  const AuraGlass({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.padding = const EdgeInsets.all(20),
    this.borderRadius,
    this.onTap,
    this.enableBlur = true,
    this.enableGradientBorder = false,
  });

  @override
  Widget build(BuildContext context) {
    final aura = context.aura;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radius = borderRadius ?? BorderRadius.circular(24);

    // Enhanced glass container with liquid transparency
    Widget content = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        // More transparent background for glass effect
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  Colors.white.withOpacity(0.08),
                  Colors.white.withOpacity(0.02),
                ]
              : [
                  Colors.white.withOpacity(0.7),
                  Colors.white.withOpacity(0.4),
                ],
        ),
        borderRadius: radius,
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.15)
              : Colors.white.withOpacity(0.8),
          width: 1.5,
        ),
        boxShadow: [
          // Outer glow shadow
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.5)
                : aura.glassShadow.withOpacity(0.1),
            blurRadius: 40,
            offset: const Offset(0, 15),
            spreadRadius: -5,
          ),
          // Inner subtle shadow for depth
          BoxShadow(
            color: isDark
                ? AuraColors.tether.withOpacity(0.05)
                : AuraColors.heartbeat.withOpacity(0.03),
            blurRadius: 20,
            offset: const Offset(0, 5),
            spreadRadius: -2,
          ),
        ],
      ),
      child: Padding(
        padding: padding,
        child: child,
      ),
    );

    // Add gradient border overlay for premium effect
    if (enableGradientBorder) {
      content = Container(
        decoration: BoxDecoration(
          borderRadius: radius,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AuraColors.tether.withOpacity(0.3),
              AuraColors.heartbeat.withOpacity(0.2),
              AuraColors.halo.withOpacity(0.3),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(1.5),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? Colors.black : aura.bgPrimary,
              borderRadius: BorderRadius.circular(22.5),
            ),
            child: content,
          ),
        ),
      );
    }

    // Wrap with InkWell if tappable
    if (onTap != null) {
      content = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          splashColor: AuraColors.halo.withOpacity(0.1),
          highlightColor: AuraColors.halo.withOpacity(0.05),
          child: content,
        ),
      );
    }

    // Apply enhanced blur effect for liquid glass look
    if (enableBlur) {
      return ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: isDark ? 15.0 : 20.0,
            sigmaY: isDark ? 15.0 : 20.0,
          ),
          child: content,
        ),
      );
    }

    return content;
  }
}

/// A variant of AuraGlass for cards with more structured content
class AuraGlassCard extends StatelessWidget {
  final Widget? header;
  final Widget body;
  final Widget? footer;
  final double? width;
  final VoidCallback? onTap;

  const AuraGlassCard({
    super.key,
    this.header,
    required this.body,
    this.footer,
    this.width,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AuraGlass(
      width: width,
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (header != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: header!,
            ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              header == null ? 20 : 0,
              20,
              footer == null ? 20 : 12,
            ),
            child: body,
          ),
          if (footer != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: footer!,
            ),
        ],
      ),
    );
  }
}
