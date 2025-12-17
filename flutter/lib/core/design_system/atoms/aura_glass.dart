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

  const AuraGlass({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.padding = const EdgeInsets.all(20),
    this.borderRadius,
    this.onTap,
    this.enableBlur = true,
  });

  @override
  Widget build(BuildContext context) {
    final aura = context.aura;
    final radius = borderRadius ?? BorderRadius.circular(24);

    Widget content = Container(
      width: width,
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: aura.bgSecondary.withOpacity(aura.glassOpacity),
        borderRadius: radius,
        border: Border.all(
          color: aura.glassBorder,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: aura.glassShadow,
            blurRadius: 30,
            offset: const Offset(0, 10),
            spreadRadius: -5,
          ),
        ],
      ),
      child: child,
    );

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

    // Apply blur effect
    if (enableBlur) {
      return ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: aura.blurIntensity,
            sigmaY: aura.blurIntensity,
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
