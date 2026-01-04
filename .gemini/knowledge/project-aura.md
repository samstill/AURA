---
description: Comprehensive Project Aura knowledge base - architecture, design system, components, and best practices
---

# 🌌 Project Aura Knowledge Base

## Overview

**Encresa Aura** is a Flutter-based AI companion app with a distinctive glassmorphic design system built around emotional themes of companionship. The app features a unique "Secretary" AI assistant that handles background tasks and notifications.

---

## Architecture

```
flutter/lib/
├── main.dart                    # App entry point
├── core/                        # Shared infrastructure
│   ├── api/                     # API client & interceptors
│   ├── auth/                    # Authentik OAuth integration
│   ├── config/                  # App configuration
│   ├── design_system/           # 🎨 AURA DESIGN SYSTEM
│   │   ├── atoms/               # UI components
│   │   ├── motion/              # Animation physics
│   │   └── theme/               # Colors & typography
│   ├── router/                  # GoRouter navigation
│   └── theme/                   # Legacy theme files
└── features/                    # Feature modules
    ├── chat/                    # Chat interface
    ├── dashboard/               # Home screen with Nucleus
    └── splash/                  # Splash/onboarding
```

---

## 🎨 Aura Design System

### Philosophy: The Emotional Palette

The design system is built around **emotional resonance**:
- **The Void** (Dark Theme): Cold, vast space where UI is the only source of warmth
- **The Mirage** (Light Theme): Warm, biological feeling like waking in warm sheets

### Semantic Colors (`aura_colors.dart`)

```dart
// Access via: context.aura.bgPrimary, context.aura.heartbeat
AuraColors.heartbeat  // #FF4D6D - Intimacy, primary actions
AuraColors.tether     // #5D5FEF - Trust/devotion, navigation
AuraColors.halo       // #00F0FF - Intelligence, AI indicators
```

| Property | Void (Dark) | Mirage (Light) |
|----------|-------------|----------------|
| `bgPrimary` | `#000000` OLED Black | `#FFF9F5` Warm Alabaster |
| `bgSecondary` | `#080808` Shadow | `#F2E8E6` Pale Blush |
| `textPrimary` | `#E1E1E1` Soft White | `#3E3436` Deep Cocoa |
| `glassOpacity` | 0.3 | 0.75 |

---

## ⚡ Motion System (`aura_motion.dart`)

### Core Principle: "The Ice"
> Elements never stop instantly - they drift to a halt like ice on smooth water.

### Duration Tokens

| Token | Duration | Use Case |
|-------|----------|----------|
| `instant` | 80ms | Immediate feedback |
| `quick` | 150ms | Quick responses |
| `standard` | 250ms | Standard transitions |
| `deliberate` | 500ms | Noticeable animations |
| `ice` | 800ms | Drift-to-halt effect |
| `dramatic` | 1000ms | Emphasis animations |

### Curve Constants

```dart
AuraMotion.easeOut     // Standard ease out
AuraMotion.iceEase     // Cubic(0.23, 1, 0.32, 1) - The Ice drift
AuraMotion.jellyBounce // Elastic out - playful bounce
AuraMotion.spring      // easeOutBack - natural spring
AuraMotion.tensionIn   // easeOutCubic - sinking feel
AuraMotion.sacrificeOut // easeOut - explosive release
```

### Animation Presets

```dart
// Tension - for high-value interactions (CTAs, cards)
AuraMotion.tension.pressDuration   // 150ms
AuraMotion.tension.pressScale      // 0.96

// Jelly - for playful elements (icons, toggles)
AuraMotion.jelly.pressDuration     // 100ms
AuraMotion.jelly.releaseCurve      // elasticOut bounce
AuraMotion.jelly.pressScale        // 0.92
```

---

## 🧩 Widget Animation Extensions (`aura_animations.dart`)

Apply animations to any widget with extension methods:

```dart
// Press animations
myWidget.withTension(onPressed: () {})   // Deep sink + shimmer
myWidget.withJelly(onPressed: () {})     // Bouncy squash
myWidget.withSubtlePress(onPressed: () {}) // Gentle press

// Entrance animations
myWidget.withIce()                       // Slow drift entrance
myWidget.withStaggeredEntrance(index: 0) // List item stagger
myWidget.withScaleEntrance()             // Pop-in scale
myWidget.withBlurEntrance()              // Focus from blur

// Continuous effects
myWidget.withShimmer()                   // Loading shimmer
myWidget.withPulse()                     // Attention pulse
myWidget.withBreathingGlow(color: c)     // Ambient glow
```

---

## 🧱 Atom Components

### AuraNucleus (`aura_nucleus.dart`)
Central AI orb/avatar that pulses and morphs. States: `silence`, `whisper`, `speaking`, `thinking`

### AuraSummarySheet (`aura_summary_sheet.dart`)
Glassmorphic expandable card below Nucleus with stat pills.

### AuraBottomSheet (`aura_bottom_sheet.dart`)
Glassmorphic modal sheet with blur and ice animation.

### AuraBottomNav (`aura_bottom_nav.dart`)
Floating glassmorphic navigation bar.

### AuraButton / AuraIconButton (`aura_button.dart`)
Primary action buttons with tension physics.

### AuraGlass (`aura_glass.dart`)
Base glassmorphic container.

### AuraToggle (`aura_toggle.dart`)
Animated toggle switch with jelly physics.

---

## 🛡️ Gesture Safety Pattern

All interactive widgets use a robust disposal pattern:

```dart
class _MyWidgetState extends State<MyWidget> {
  bool _isPressed = false;
  bool _isDisposed = false;  // ✅ Disposal flag

  void _safeSetState(VoidCallback fn) {
    if (_isDisposed || !mounted) return;
    try { setState(fn); } catch (_) {}
  }

  @override
  void dispose() {
    _isDisposed = true;  // ✅ Set BEFORE super.dispose()
    super.dispose();
  }
}
```

---

## 🔧 Best Practices

### DO ✅
- Use `context.aura.xxx` for all colors
- Use `AuraMotion.xxx` for all durations/curves
- Use `.withIce()` for entrance animations
- Add `_isDisposed` flag to StatefulWidgets with gestures

### DON'T ❌
- Hardcode colors or durations
- Use raw `setState()` in gesture handlers
- Use `.withJelly()` inside ScrollViews

---

## 🔐 Authentication

Uses **Authentik** OAuth2 with:
- Session cookies in `flutter_secure_storage`
- 7-day offline grace period
- Background session validation
- Custom flow at `auth.encresa.com`

---

*Last Updated: January 2026*
