/// Project Aura - AuraIcon Atom
/// =============================
/// A semantic icon wrapper that enforces the design system colors.
/// Uses Lucide icons for their clean, geometric lines that align
/// with the glassmorphic aesthetic.
///
/// Usage:
/// ```dart
/// AuraIcon(LucideIcons.home)
/// AuraIcon(LucideIcons.heart, style: AuraIconStyle.heartbeat)
/// AuraIcon(LucideIcons.sparkles, style: AuraIconStyle.halo)
/// ```

import 'package:flutter/material.dart';
import '../theme/aura_colors.dart';

/// Semantic icon styles that map to the design system colors
enum AuraIconStyle {
  /// Uses Text Primary Color (Default)
  primary,

  /// Uses Semantic "Heartbeat" (Action/Love)
  heartbeat,

  /// Uses Semantic "Tether" (Trust/Structure)
  tether,

  /// Uses Semantic "Halo" (AI/Guide/Intelligence)
  halo,

  /// Uses Text Secondary (Subtle/Glass)
  glass,
}

/// A semantic icon wrapper that enforces design system colors.
/// 
/// Prefer using this over raw `Icon()` widgets to maintain
/// consistent styling across the application.
class AuraIcon extends StatelessWidget {
  /// The icon to display (use LucideIcons.xxx)
  final IconData icon;

  /// The semantic style determining the icon color
  final AuraIconStyle style;

  /// The size of the icon (default: 24.0)
  final double size;

  /// Optional custom color override (use sparingly)
  final Color? customColor;

  const AuraIcon(
    this.icon, {
    super.key,
    this.style = AuraIconStyle.primary,
    this.size = 24.0,
    this.customColor,
  });

  /// Creates a heartbeat-styled icon (action/love)
  const AuraIcon.heartbeat(
    this.icon, {
    super.key,
    this.size = 24.0,
    this.customColor,
  }) : style = AuraIconStyle.heartbeat;

  /// Creates a tether-styled icon (trust/structure)
  const AuraIcon.tether(
    this.icon, {
    super.key,
    this.size = 24.0,
    this.customColor,
  }) : style = AuraIconStyle.tether;

  /// Creates a halo-styled icon (AI/guide)
  const AuraIcon.halo(
    this.icon, {
    super.key,
    this.size = 24.0,
    this.customColor,
  }) : style = AuraIconStyle.halo;

  /// Creates a glass-styled icon (subtle/secondary)
  const AuraIcon.glass(
    this.icon, {
    super.key,
    this.size = 24.0,
    this.customColor,
  }) : style = AuraIconStyle.glass;

  Color _getColor(BuildContext context) {
    if (customColor != null) return customColor!;

    final aura = context.aura;

    switch (style) {
      case AuraIconStyle.primary:
        return aura.textPrimary;
      case AuraIconStyle.heartbeat:
        return AuraColors.heartbeat;
      case AuraIconStyle.tether:
        return AuraColors.tether;
      case AuraIconStyle.halo:
        return AuraColors.halo;
      case AuraIconStyle.glass:
        return aura.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Icon(
      icon,
      color: _getColor(context),
      size: size,
    );
  }
}

/// Extension to easily convert any IconData to AuraIcon
extension IconDataToAuraIcon on IconData {
  /// Convert to AuraIcon with primary style
  AuraIcon toAura({
    AuraIconStyle style = AuraIconStyle.primary,
    double size = 24.0,
  }) {
    return AuraIcon(this, style: style, size: size);
  }

  /// Convert to AuraIcon with heartbeat style
  AuraIcon get asHeartbeat => AuraIcon.heartbeat(this);

  /// Convert to AuraIcon with tether style
  AuraIcon get asTether => AuraIcon.tether(this);

  /// Convert to AuraIcon with halo style
  AuraIcon get asHalo => AuraIcon.halo(this);

  /// Convert to AuraIcon with glass style
  AuraIcon get asGlass => AuraIcon.glass(this);
}
