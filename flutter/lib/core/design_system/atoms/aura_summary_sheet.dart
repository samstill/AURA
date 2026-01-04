/// Project Aura - Summary Sheet Component
/// ========================================
/// Glassmorphic summary card that appears below the Nucleus.
///
/// Features:
/// - Expandable with "Ice" easing animation
/// - Header with title + expand icon
/// - Content area with analysis text
/// - Stat pills (Tasks, Unread counts)
/// - Theme-aware glass styling
library;

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../motion/aura_motion.dart';
import '../theme/aura_colors.dart';

/// A stat item for the summary sheet
class SummaryStatItem {
  final String label;
  final dynamic value;
  final Color? valueColor;
  final VoidCallback? onTap;

  const SummaryStatItem({
    required this.label,
    required this.value,
    this.valueColor,
    this.onTap,
  });
}

/// Glassmorphic summary sheet with expandable content
class AuraSummarySheet extends StatefulWidget {
  /// Title displayed in the header
  final String title;

  /// Section label (e.g., "ANALYSIS")
  final String? sectionLabel;

  /// Main content text
  final String content;

  /// Stat items to display
  final List<SummaryStatItem> stats;

  /// Callback when expand button is pressed
  final VoidCallback? onExpand;

  /// Initial expanded state
  final bool initiallyExpanded;

  /// Maximum lines of content when collapsed
  final int maxLinesCollapsed;

  const AuraSummarySheet({
    super.key,
    this.title = 'Summary',
    this.sectionLabel,
    required this.content,
    this.stats = const [],
    this.onExpand,
    this.initiallyExpanded = true,
    this.maxLinesCollapsed = 3,
  });

  @override
  State<AuraSummarySheet> createState() => _AuraSummarySheetState();
}

class _AuraSummarySheetState extends State<AuraSummarySheet>
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
      begin: const Offset(0, 0.1),
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

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: _getBackgroundColor(isDark),
                  borderRadius: BorderRadius.circular(24),
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
                      offset: const Offset(0, -10),
                    ),
                    // Inner top highlight for 3D effect
                    BoxShadow(
                      color: Colors.white.withOpacity(isDark ? 0.1 : 0.6),
                      blurRadius: 0,
                      offset: const Offset(0, -1),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    _buildHeader(context, isDark),

                    // Content
                    _buildContent(context, isDark),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark) {
    // OLD: final textColor = isDark ? const Color(0xFFE1E1E1) : const Color(0xFF3E3436);
    final aura = context.aura;

    return InkWell(
      onTap: widget.onExpand,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
        child: Row(
          children: [
            // Decorative accent bar
            Container(
              width: 3,
              height: 24,
              decoration: BoxDecoration(
                color: aura.textPrimary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),

            // Title
            Expanded(
              child: Text(
                widget.title,
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                  color: aura.textPrimary,
                  letterSpacing: 0.5,
                ),
              ),
            ),

            // Expand button
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: aura.textPrimary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                LucideIcons.maximize2,
                size: 20,
                color: aura.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, bool isDark) {
    final aura = context.aura;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section label
          if (widget.sectionLabel != null) ...[
            Text(
              widget.sectionLabel!.toUpperCase(),
              style: TextStyle(
                fontFamily: 'Jura',
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: aura.textPrimary.withValues(alpha: 0.6),
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 8),
          ],

          // Main content
          Text(
            widget.content,
            maxLines: widget.initiallyExpanded ? null : widget.maxLinesCollapsed,
            overflow: widget.initiallyExpanded ? null : TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 16,
              height: 1.6,
              color: aura.textPrimary.withValues(alpha: 0.8),
            ),
          ),

          // Stats row
          if (widget.stats.isNotEmpty) ...[
            const SizedBox(height: 16),
            Row(
              children: widget.stats
                  .map((stat) => Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: _buildStatPill(context, stat, isDark),
                        ),
                      ))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatPill(BuildContext context, SummaryStatItem stat, bool isDark) {
    final aura = context.aura;

    return _TappableStatPill(
      onTap: stat.onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: aura.textPrimary.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: aura.textPrimary.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              stat.label.toUpperCase(),
              style: TextStyle(
                fontFamily: 'Jura',
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: aura.textPrimary.withValues(alpha: 0.6),
                letterSpacing: 1,
              ),
            ),
            Text(
              stat.value.toString(),
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: stat.valueColor ?? aura.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getBackgroundColor(bool isDark) {
    // We can rely on context.aura.bgSecondary and its specific opacity
    return isDark
        ? const Color(0xFF141414).withValues(alpha: 0.3)
        : Colors.white.withValues(alpha: 0.6);
  }

  Color _getBorderColor(bool isDark) {
     // Use context.aura.glassBorder
     // But wait, the original logic had manual overrides. 
     // Let's stick to the Design System's glassBorder if possible, 
     // or just allow the ThemeExtension to handle it.
     // In AuraColors:
     // Dark: glassBorder = 0.08
     // Light: glassBorder = 0.8
     // This matches the intent.
     // However, the original code had:
     // Dark: 0.08
     // Light: 0.4
     // I will trust AuraColors.
    return isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.white.withValues(alpha: 0.4);
  }
}

/// A tappable stat pill with jelly animation that works reliably in scrollable areas.
class _TappableStatPill extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  const _TappableStatPill({
    required this.child,
    this.onTap,
  });

  @override
  State<_TappableStatPill> createState() => _TappableStatPillState();
}

class _TappableStatPillState extends State<_TappableStatPill> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) {
        if (widget.onTap != null) {
          setState(() => _isPressed = true);
          HapticFeedback.selectionClick();
        }
      },
      onTapUp: (_) {
        if (widget.onTap != null) {
          setState(() => _isPressed = false);
        }
      },
      onTapCancel: () {
        if (widget.onTap != null) {
          setState(() => _isPressed = false);
        }
      },
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _isPressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
