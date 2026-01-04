/// Project Aura - Bottom Sheet Component
/// ======================================
/// A glassmorphic bottom sheet with Aura physics and animations.
///
/// Features:
/// - Backdrop blur effect
/// - Glassmorphic styling
/// - Header with icon and title
/// - Customizable content
/// - Ice entrance animation
library;

import 'dart:ui';
import 'package:flutter/material.dart';
import '../motion/aura_animations.dart';
import '../theme/aura_colors.dart';
import 'aura_glass.dart';

/// Shows an Aura-styled glassmorphic bottom sheet.
///
/// Usage:
/// ```dart
/// showAuraBottomSheet(
///   context: context,
///   title: 'Pending Tasks',
///   icon: LucideIcons.checkSquare,
///   child: ListView.builder(...),
/// );
/// ```
Future<T?> showAuraBottomSheet<T>({
  required BuildContext context,
  required String title,
  required IconData icon,
  required Widget child,
  Color? iconColor,
  double maxHeightFactor = 0.6,
  bool showCount = false,
  int? count,
}) {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => _AuraBottomSheetContent(
      title: title,
      icon: icon,
      iconColor: iconColor,
      maxHeightFactor: maxHeightFactor,
      showCount: showCount,
      count: count,
      child: child,
    ),
  );
}

/// Shows an Aura bottom sheet with a list of items.
///
/// Convenience wrapper that handles list rendering with staggered animations.
Future<T?> showAuraListBottomSheet<T, I>({
  required BuildContext context,
  required String title,
  required IconData icon,
  required List<I> items,
  required Widget Function(I item, int index) itemBuilder,
  Color? iconColor,
  double maxHeightFactor = 0.6,
  String emptyMessage = 'Nothing here yet',
}) {
  final aura = context.aura;

  return showAuraBottomSheet<T>(
    context: context,
    title: title,
    icon: icon,
    iconColor: iconColor,
    maxHeightFactor: maxHeightFactor,
    showCount: true,
    count: items.length,
    child: items.isEmpty
        ? Padding(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: Text(
                emptyMessage,
                style: TextStyle(
                  fontFamily: 'Manrope',
                  color: aura.textPrimary.withValues(alpha: 0.5),
                ),
              ),
            ),
          )
        : ListView.separated(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) =>
                itemBuilder(items[index], index).withStaggeredEntrance(index: index),
          ),
  );
}

class _AuraBottomSheetContent extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color? iconColor;
  final double maxHeightFactor;
  final bool showCount;
  final int? count;
  final Widget child;

  const _AuraBottomSheetContent({
    required this.title,
    required this.icon,
    this.iconColor,
    required this.maxHeightFactor,
    required this.showCount,
    this.count,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final aura = context.aura;
    final color = iconColor ?? AuraColors.tether;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      child: BackdropFilter(
        // Increased blur for stronger frosted glass effect
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * maxHeightFactor,
          ),
          decoration: BoxDecoration(
            // Gradient fill for refraction-like depth effect
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: isDark
                  ? [
                      Colors.white.withValues(alpha: 0.08),
                      Colors.white.withValues(alpha: 0.03),
                      aura.bgSecondary.withValues(alpha: 0.2),
                    ]
                  : [
                      Colors.white.withValues(alpha: 0.7),
                      Colors.white.withValues(alpha: 0.5),
                      Colors.white.withValues(alpha: 0.3),
                    ],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.15)
                  : Colors.white.withValues(alpha: 0.8),
              width: 1.5,
            ),
            boxShadow: [
              // Top inner glow for glass edge highlight
              BoxShadow(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.white.withValues(alpha: 0.5),
                blurRadius: 1,
                offset: const Offset(0, 1),
                spreadRadius: 0,
              ),
              // Outer shadow for depth
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.15),
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar with glass-like shimmer
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      aura.textPrimary.withValues(alpha: 0.2),
                      aura.textPrimary.withValues(alpha: 0.4),
                      aura.textPrimary.withValues(alpha: 0.2),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    // Icon with glass-like container
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            color.withValues(alpha: 0.3),
                            color.withValues(alpha: 0.1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: color.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Icon(icon, color: color, size: 20),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      title,
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: aura.textPrimary,
                      ),
                    ),
                    if (showCount && count != null) ...[
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: aura.textPrimary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '$count',
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: aura.textPrimary.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Content
              Flexible(child: child),
            ],
          ),
        ),
      ),
    ).withIce();
  }
}

/// A glassmorphic list item for use in bottom sheets.
class AuraSheetItem extends StatelessWidget {
  final Widget? leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const AuraSheetItem({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final aura = context.aura;

    return AuraGlass(
      padding: const EdgeInsets.all(16),
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Row(
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(width: 16),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: aura.textPrimary,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 13,
                      color: aura.textPrimary.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
