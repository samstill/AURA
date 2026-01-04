/// Project Aura - Bottom Navigation Component
/// ============================================
/// Floating glassmorphic bottom navigation bar.
///
/// Features:
/// - Animated pill indicator that follows active tab
/// - Jelly squash on tap (0.92 scale)
/// - Label appears/disappears with tab activation
/// - Ice entrance animation from off-screen
library;

import 'dart:ui';
import 'package:flutter/material.dart';
import '../motion/aura_motion.dart';
import '../theme/aura_colors.dart';

/// Navigation item configuration
class AuraNavItem {
  final IconData icon;
  final String label;
  final String? tooltip;

  const AuraNavItem({
    required this.icon,
    required this.label,
    this.tooltip,
  });
}

/// Floating glassmorphic bottom navigation
class AuraBottomNav extends StatefulWidget {
  /// List of navigation items
  final List<AuraNavItem> items;

  /// Currently selected index
  final int selectedIndex;

  /// Callback when a tab is selected
  final ValueChanged<int>? onTabChanged;

  const AuraBottomNav({
    super.key,
    required this.items,
    this.selectedIndex = 0,
    this.onTabChanged,
  });

  @override
  State<AuraBottomNav> createState() => _AuraBottomNavState();
}

class _AuraBottomNavState extends State<AuraBottomNav>
    with SingleTickerProviderStateMixin {
  late AnimationController _entranceController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // Ice entrance animation
    _entranceController = AnimationController(
      vsync: this,
      duration: AuraMotion.ice,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entranceController,
      curve: AuraMotion.iceEase,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _entranceController,
      curve: AuraMotion.iceEase,
    ));

    // Start entrance animation
    _entranceController.forward();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Positioned(
      left: 0,
      right: 0,
      bottom: 24,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(40),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: _getBackgroundColor(isDark),
                    borderRadius: BorderRadius.circular(40),
                    border: Border.all(
                      color: _getBorderColor(isDark),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isDark
                            ? Colors.black.withValues(alpha: 0.5)
                            : const Color(0xFFA67C82).withValues(alpha: 0.15),
                        blurRadius: 40,
                        offset: const Offset(0, 10),
                      ),
                      // Inner top highlight
                      BoxShadow(
                        color: Colors.white.withOpacity(isDark ? 0.1 : 0.6),
                        blurRadius: 0,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(
                      widget.items.length,
                      (index) => _NavItemWidget(
                        item: widget.items[index],
                        isActive: index == widget.selectedIndex,
                        isDark: isDark,
                        onTap: () => widget.onTabChanged?.call(index),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _getBackgroundColor(bool isDark) {
    return isDark
        ? const Color(0xFF141414).withValues(alpha: 0.6)
        : Colors.white.withValues(alpha: 0.8);
  }

  Color _getBorderColor(bool isDark) {
    return isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.white.withValues(alpha: 0.4);
  }
}

/// Individual navigation item with jelly animation
class _NavItemWidget extends StatefulWidget {
  final AuraNavItem item;
  final bool isActive;
  final bool isDark;
  final VoidCallback? onTap;

  const _NavItemWidget({
    required this.item,
    required this.isActive,
    required this.isDark,
    this.onTap,
  });

  @override
  State<_NavItemWidget> createState() => _NavItemWidgetState();
}

class _NavItemWidgetState extends State<_NavItemWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _pressController = AnimationController(
      vsync: this,
      duration: AuraMotion.instant, // Was: 100ms
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: AuraMotion.jellySquash,
    ).animate(CurvedAnimation(
      parent: _pressController,
      curve: AuraMotion.easeOut,
    ));
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    _pressController.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    _pressController.reverse();
    widget.onTap?.call();
  }

  void _handleTapCancel() {
    _pressController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final aura = context.aura;
    // OLD: final textColor = widget.isDark ? const Color(0xFFE1E1E1) : const Color(0xFF3E3436);
    final textColor = aura.textPrimary;

    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Stack(
          children: [
            // Active pill background
            AnimatedContainer(
              duration: AuraMotion.standard,
              curve: AuraMotion.easeOut, // Was: Curves.easeOutCubic
              padding: EdgeInsets.symmetric(
                horizontal: widget.isActive ? 16 : 12,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: widget.isActive
                    ? aura.textPrimary.withValues(alpha: 0.05) // Universal active state tint
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Icon
                  Icon(
                    widget.item.icon,
                    size: 20,
                    color: widget.isActive
                        ? textColor
                        : textColor.withValues(alpha: 0.5),
                  ),

                  // Label (animated)
                  AnimatedSize(
                    duration: AuraMotion.standard,
                    curve: AuraMotion.easeOut, // Was: Curves.easeOutCubic
                    child: widget.isActive
                        ? Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: AnimatedOpacity(
                              duration: AuraMotion.quick,
                              opacity: widget.isActive ? 1.0 : 0.0,
                              child: Text(
                                widget.item.label,
                                style: TextStyle(
                                  fontFamily: 'Manrope',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: textColor,
                                ),
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A scaffold wrapper that includes the AuraBottomNav
class AuraNavScaffold extends StatelessWidget {
  final Widget body;
  final List<AuraNavItem> navItems;
  final int selectedIndex;
  final ValueChanged<int>? onTabChanged;

  const AuraNavScaffold({
    super.key,
    required this.body,
    required this.navItems,
    this.selectedIndex = 0,
    this.onTabChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        body,
        AuraBottomNav(
          items: navItems,
          selectedIndex: selectedIndex,
          onTabChanged: onTabChanged,
        ),
      ],
    );
  }
}
