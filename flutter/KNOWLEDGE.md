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
The central AI orb/avatar that pulses and morphs.

```dart
AuraNucleus(
  isActive: true,
  voiceState: NucleusVoiceState.speaking,
  size: 100,
  onActivate: () {},
  onTap: () {},
)
```

States: `silence`, `whisper`, `speaking`, `thinking`

### AuraSummarySheet (`aura_summary_sheet.dart`)
Glassmorphic expandable card below Nucleus.

```dart
AuraSummarySheet(
  title: 'Summary',
  content: 'Analysis text...',
  stats: [
    SummaryStatItem(label: 'Tasks', value: 3, onTap: () {}),
    SummaryStatItem(label: 'Unread', value: 2, valueColor: AuraColors.tether),
  ],
  onExpand: () {},
)
```

### AuraBottomSheet (`aura_bottom_sheet.dart`)
Glassmorphic modal sheet with blur and ice animation.

```dart
showAuraListBottomSheet(
  context: context,
  title: 'Notifications',
  icon: LucideIcons.bell,
  items: notifications,
  itemBuilder: (item, i) => AuraSheetItem(...),
)
```

### AuraBottomNav (`aura_bottom_nav.dart`)
Floating glassmorphic navigation bar.

```dart
AuraBottomNav(
  currentIndex: 0,
  onTap: (i) => navigateTo(i),
)
```

### AuraButton (`aura_button.dart`)
Primary action buttons with tension physics.

```dart
AuraButton(
  text: 'Continue',
  onPressed: () {},
  variant: AuraButtonVariant.heartbeat,
  isLoading: false,
)

AuraIconButton(
  icon: LucideIcons.settings,
  onPressed: () {},
)
```

### AuraGlass (`aura_glass.dart`)
Base glassmorphic container.

```dart
AuraGlass(
  padding: EdgeInsets.all(16),
  borderRadius: BorderRadius.circular(16),
  child: content,
)
```

### AuraToggle (`aura_toggle.dart`)
Animated toggle switch with jelly physics.

```dart
AuraToggle(
  value: isDark,
  onChanged: (v) => setTheme(v),
)
```

---

## 🛡️ Gesture Safety Pattern

All interactive widgets use a robust disposal pattern to prevent `setState() during widget tree locked` errors:

```dart
class _MyWidgetState extends State<MyWidget> {
  bool _isPressed = false;
  bool _isDisposed = false;  // ✅ Disposal flag

  void _safeSetState(VoidCallback fn) {
    if (_isDisposed || !mounted) return;
    try {
      setState(fn);
    } catch (_) {}  // Silently handle edge cases
  }

  @override
  void dispose() {
    _isDisposed = true;  // ✅ Set BEFORE super.dispose()
    super.dispose();
  }

  void _handleTapCancel() {
    if (_isDisposed) return;  // ✅ Check before setState
    _safeSetState(() => _isPressed = false);
  }
}
```

**Applied to:** `AuraPressable`, `AuraButton`, `AuraIconButton`, `AuraJellyButton`, `AuraNucleus`

---

## 📱 Feature: Dashboard

### Home Tab Structure
```
HomeTab
├── AuraNucleus (AI orb with voice states)
└── AuraSummarySheet
    ├── Header (title + expand button)
    ├── Content (analysis text)
    └── Stat Pills (Tasks, Unread)
        └── onTap → opens AuraBottomSheet
```

### Data Flow
- **Tasks**: Secretary's currently processing background tasks
- **Unread**: Notifications including completed secretary tasks

---

## 🎨 Glassmorphism Recipe

For bottom sheets and floating elements:

```dart
ClipRRect(
  borderRadius: BorderRadius.circular(32),
  child: BackdropFilter(
    filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
    child: Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
            ? [Colors.white.withOpacity(0.08), Colors.white.withOpacity(0.03)]
            : [Colors.white.withOpacity(0.7), Colors.white.withOpacity(0.3)],
        ),
        border: Border.all(
          color: Colors.white.withOpacity(isDark ? 0.15 : 0.8),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(color: Colors.white.withOpacity(0.1), offset: Offset(0, 1)),
          BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20),
        ],
      ),
    ),
  ),
).withIce()
```

---

## 🔧 Best Practices

### DO ✅
- Use `context.aura.xxx` for all colors
- Use `AuraMotion.xxx` for all durations/curves
- Use `.withIce()` for entrance animations
- Use `.withStaggeredEntrance(index: i)` for lists
- Add `_isDisposed` flag to all StatefulWidgets with gestures

### DON'T ❌
- Hardcode `Duration(milliseconds: ...)` - use `AuraMotion.standard`
- Hardcode `Colors.xxx` - use `context.aura.textPrimary`
- Use raw `setState()` in gesture handlers - use `_safeSetState()`
- Use `.withJelly()` inside ScrollViews - create dedicated tappable widget

---

## 📦 Dependencies

Key packages used:
- `flutter_animate` - Declarative animations
- `go_router` - Navigation
- `flutter_riverpod` - State management
- `lucide_icons` - Icon set
- `flutter_secure_storage` - Secure persistence
- `dio` - HTTP client

---

## 🔐 Authentication

Uses **Authentik** OAuth2 with:
- Session cookies stored in `flutter_secure_storage`
- 7-day offline grace period
- Background session validation
- Custom Authentik flow at `auth.encresa.com`

---

## 📝 File Naming Conventions

| Type | Pattern | Example |
|------|---------|---------|
| Atoms | `aura_*.dart` | `aura_button.dart` |
| Screens | `*_screen.dart` | `home_screen.dart` |
| Tabs | `*_tab.dart` | `home_tab.dart` |
| Controllers | `*_controller.dart` | `auth_controller.dart` |
| Models | `*.dart` (no suffix) | `user.dart` |

---

## 🚀 Running the App

```bash
cd flutter
flutter pub get
flutter run

# For release build
flutter build apk --release
```

---

*Last Updated: January 2026*
