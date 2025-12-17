# Project Aura: Design System Implementation Guide

> **"The Tactical Implementation of Desire"**

This document codifies the psychological design philosophy into reusable Flutter components for Project Aura.

---

## Table of Contents

1. [Philosophy Overview](#philosophy-overview)
2. [Dependencies](#dependencies)
3. [Color System](#color-system)
4. [Typography](#typography)
5. [Motion & Haptics](#motion--haptics)
6. [Components](#components)
7. [Theme Management](#theme-management)
8. [Usage Examples](#usage-examples)

---

## Philosophy Overview

The Aura Design System maps colors to the emotional cycle of **Loneliness** (The Void) and **Companionship** (The Cure). Every interaction is designed to feel intentional and tactile.

### The Dual Worlds

| Theme | Codename | Psychology |
|-------|----------|------------|
| **Dark Mode** | The Void | Cold, vast space where the UI becomes the only source of warmth |
| **Light Mode** | The Mirage | Warm, biological feel like waking up in warm sheets |

### The Emotional Accents

| Name | Hex | Purpose |
|------|-----|---------|
| **Heartbeat** | `#FF4D6D` | Action, Love, Primary CTAs |
| **Tether** | `#5D5FEF` | Trust, Structure, Navigation |
| **Halo** | `#00F0FF` | Intelligence, AI Indicators, Focus |

---

## Dependencies

Add these to `flutter/pubspec.yaml`:

```yaml
dependencies:
  # Typography
  google_fonts: ^6.1.0
  
  # Motion & Animations
  flutter_animate: ^4.5.0
  
  # Icons
  lucide_icons: ^0.257.0
```

---

## Color System

### File: `lib/core/design_system/theme/aura_colors.dart`

Uses Flutter's `ThemeExtension` for semantic color access.

### Void Theme (Dark)

| Property | Value | Description |
|----------|-------|-------------|
| `bgPrimary` | `#000000` | OLED Infinite - pure black |
| `bgSecondary` | `#080808` | Shadow - barely visible elevation |
| `textPrimary` | `#E1E1E1` | Softened white - reduces eye strain |
| `glassBorder` | `rgba(255,255,255,0.08)` | Sharp, faint borders |
| `glassShadow` | Pure Black | Deep merging shadows |
| `glassOpacity` | `0.3` | Low opacity for void feel |

### Mirage Theme (Light)

| Property | Value | Description |
|----------|-------|-------------|
| `bgPrimary` | `#FFF9F5` | Warm Alabaster - skin-tone base |
| `bgSecondary` | `#F2E8E6` | Pale Blush - biological, tender |
| `textPrimary` | `#3E3436` | Deep Cocoa - warmer than black |
| `glassBorder` | `rgba(255,255,255,0.8)` | High contrast borders |
| `glassShadow` | `rgba(166,124,130,0.15)` | Subsurface scattering |
| `glassOpacity` | `0.75` | High opacity to prevent bleed |

### Usage

```dart
import 'package:project_aura/core/design_system/design_system.dart';

// Access semantic colors via BuildContext
Container(color: context.aura.bgPrimary);
Text("Hello", style: TextStyle(color: context.aura.textSecondary));

// Static accent colors
Icon(Icons.favorite, color: AuraColors.heartbeat);
```

---

## Typography

### File: `lib/core/design_system/theme/aura_typography.dart`

### The Trinity of Seduction

| Role | Font | Purpose |
|------|------|---------|
| **The Inviter** | Outfit | Headings - Geometric with "Baby Face" circular dots |
| **The Narrator** | Manrope | Body text - Neutral and legible |
| **The Protector** | Jura | Labels/Data - Wide structure with soft terminals |

### Text Styles Mapping

| TextTheme | Font | Size | Weight |
|-----------|------|------|--------|
| `displayLarge` | Outfit | 57 | Bold |
| `headlineLarge` | Outfit | 32 | SemiBold |
| `titleLarge` | Outfit | 22 | Medium |
| `bodyLarge` | Manrope | 16 | Normal |
| `bodyMedium` | Manrope | 14 | Normal |
| `labelLarge` | Jura | 14 | SemiBold |

### Usage

```dart
Text(
  "Welcome to AURA",
  style: Theme.of(context).textTheme.displayLarge,
);
```

---

## Motion & Haptics

### Files

| File | Purpose |
|------|---------|
| `motion/aura_haptics.dart` | Centralized haptic patterns |
| `motion/aura_motion.dart` | Motion constants and curves |
| `motion/aura_pressable.dart` | Reusable press wrapper |
| `motion/aura_animations.dart` | Widget extension methods |

### Motion Presets

#### The Ice (Global Momentum)
Elements never stop instantly - they drift to a halt.
- Duration: 800ms
- Curve: `cubic-bezier(0.23, 1, 0.32, 1)`

#### Tension & Sacrifice (Primary Actions)
High-value interactions feel heavy and consequential.

| Phase | Action | Effect |
|-------|--------|--------|
| **Tension** | Press | Scale to 0.96, shadow disappears, light haptic |
| **Sacrifice** | Release | Shimmer ripple, medium haptic |

#### The Jelly (Icon Buttons)
Playful, low-risk interactions with bounce.

| Phase | Action | Effect |
|-------|--------|--------|
| **Squash** | Press | Scale to 0.92, selection haptic |
| **Wiggle** | Release | Elastic bounce back |

### Haptic Patterns

```dart
import 'package:project_aura/core/design_system/design_system.dart';

AuraHaptics.tension();    // Light impact on press
AuraHaptics.sacrifice();  // Medium impact on release
AuraHaptics.jelly();      // Selection click
AuraHaptics.heavy();      // Important actions
```

### Widget Extensions

```dart
// Apply Tension physics to any widget
MyCard().withTension(onPressed: () => print("Pressed!"))

// Apply Jelly physics
Icon(LucideIcons.star).withJelly(onPressed: () {})

// Apply "Ice" entrance animation
MyWidget().withIce()

// Staggered list animations
ListView.builder(
  itemBuilder: (ctx, i) => ListTile(...).withStaggeredEntrance(index: i),
)

// Other effects
widget.withScaleEntrance()
widget.withBlurEntrance()
widget.withShimmer()
widget.withPulse()
widget.withBreathingGlow(color: AuraColors.halo)
```

### Pressable Wrapper

```dart
AuraPressable(
  style: PressableStyle.tension,  // or .jelly, .subtle
  onPressed: () {},
  enableHaptics: true,
  enableShimmer: true,
  child: MyCustomCard(),
)
```

---

## Components

### AuraGlass

Glassmorphic container that auto-adjusts based on theme.

```dart
AuraGlass(
  padding: EdgeInsets.all(24),
  borderRadius: BorderRadius.circular(32),
  onTap: () {},
  child: Text("Floating in the Void"),
)

// Structured card variant
AuraGlassCard(
  header: Text("Title"),
  body: Text("Content"),
  footer: AuraButton(...),
)
```

### AuraButton

Tension & Sacrifice button with physics-based animations.

```dart
// Primary action (Heartbeat color)
AuraButton.heartbeat(
  label: "INITIALIZE",
  onPressed: () {},
  icon: LucideIcons.play,
)

// Secondary action (Tether color)
AuraButton.tether(
  label: "CONFIGURE",
  onPressed: () {},
)

// Ghost variant
AuraButton.ghost(
  label: "CANCEL",
  onPressed: () {},
)

// With loading state
AuraButton(
  label: "SUBMIT",
  onPressed: _submit,
  isLoading: _isLoading,
  fullWidth: true,
)
```

### AuraIconButton

Jelly physics for navigation and status elements.

```dart
AuraIconButton(
  icon: LucideIcons.settings,
  onPressed: () {},
  tooltip: "Settings",
)
```

### AuraJellyButton

Icon button with exact CSS-like "jelly" wobble animation on press.

```dart
// Standard jelly button
AuraJellyButton(
  icon: AuraIcon(LucideIcons.bell),
  onTap: () {},
  tooltip: "Notifications",
)

// Active state (with subtle background)
AuraJellyButton(
  active: true,
  icon: AuraIcon(LucideIcons.layoutDashboard, style: AuraIconStyle.heartbeat),
  onTap: () {},
)
```

### AuraToggle

Liquid morph toggle switch with "conservation of mass" physics.

```dart
// Theme toggle example
AuraToggle(
  value: isDarkMode,
  onChanged: (val) {
    ref.read(themeModeProvider.notifier).toggle();
  },
)

// Simple switch without internal icons
AuraSwitch(
  value: isEnabled,
  onChanged: (val) => setState(() => isEnabled = val),
  activeColor: AuraColors.heartbeat,
)
```

### AuraIcon

Semantic icon wrapper for consistent styling.

```dart
import 'package:lucide_icons/lucide_icons.dart';

// Standard icon
AuraIcon(LucideIcons.home)

// With semantic color
AuraIcon.heartbeat(LucideIcons.heart)
AuraIcon.tether(LucideIcons.link)
AuraIcon.halo(LucideIcons.sparkles)
AuraIcon.glass(LucideIcons.settings)

// Using extension
LucideIcons.brain.asHalo
```

### AuraScaffold

Scaffold with atmospheric gradient background.

```dart
AuraScaffold(
  appBar: AppBar(title: Text("Dashboard")),
  body: Column(...),
  floatingActionButton: FloatingActionButton(...),
)
```

### AuraBackground

Direct background gradient usage.

```dart
AuraBackground(
  useGradient: true,
  child: Scaffold(
    backgroundColor: Colors.transparent,
    body: YourContent(),
  ),
)

// Animated transitions
AuraAnimatedBackground(
  duration: Duration(milliseconds: 800),
  child: YourContent(),
)
```

---

## Theme Management

### File: `lib/core/design_system/theme/theme_controller.dart`

Riverpod provider for theme mode management.

### Reading Theme Mode

```dart
class MyWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    
    return Text("Current: ${themeMode.label}");
    // "System", "Light", or "Dark"
  }
}
```

### Changing Theme Mode

```dart
// Set specific mode
ref.read(themeModeProvider.notifier).setLight();
ref.read(themeModeProvider.notifier).setDark();
ref.read(themeModeProvider.notifier).setSystem();

// Toggle between light/dark
ref.read(themeModeProvider.notifier).toggle();

// Cycle: system -> light -> dark -> system
ref.read(themeModeProvider.notifier).cycle();
```

### Theme Mode Labels (for Settings UI)

```dart
final mode = ref.watch(themeModeProvider);

Text(mode.label);       // "System", "Light", "Dark"
Text(mode.description); // "The Void - Cold & Infinite", etc.
```

### Default Behavior

- **Default:** `ThemeMode.system` (follows device settings)
- The Void (dark) is activated when device is in dark mode
- The Mirage (light) is activated when device is in light mode

---

## Usage Examples

### Complete Screen Example

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:project_aura/core/design_system/design_system.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AuraScaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with entrance animation
              Text(
                "Welcome Back",
                style: Theme.of(context).textTheme.displaySmall,
              ).withIce(),
              
              const SizedBox(height: 32),
              
              // Status card with glass effect
              AuraGlass(
                child: Row(
                  children: [
                    AuraIcon.halo(LucideIcons.brain, size: 32),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "AURA Status",
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                          Text(
                            "Online & Ready",
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ).withStaggeredEntrance(index: 0),
              
              const SizedBox(height: 24),
              
              // Action buttons
              AuraButton.heartbeat(
                label: "START CONVERSATION",
                icon: LucideIcons.messageCircle,
                onPressed: () {},
                fullWidth: true,
              ).withStaggeredEntrance(index: 1),
              
              const SizedBox(height: 12),
              
              AuraButton.ghost(
                label: "VIEW SETTINGS",
                icon: LucideIcons.settings,
                onPressed: () {},
                fullWidth: true,
              ).withStaggeredEntrance(index: 2),
            ],
          ),
        ),
      ),
    );
  }
}
```

---

## Directory Structure

```
flutter/lib/core/design_system/
├── theme/
│   ├── aura_colors.dart        # Semantic color palette
│   ├── aura_typography.dart    # Font system
│   ├── app_theme.dart          # Theme factory
│   ├── theme_controller.dart   # Riverpod provider
│   └── aura_background.dart    # Gradient backgrounds
├── motion/
│   ├── aura_haptics.dart       # Haptic patterns
│   ├── aura_motion.dart        # Motion constants
│   ├── aura_pressable.dart     # Press wrapper
│   ├── aura_animations.dart    # Widget extensions
│   └── motion.dart             # Barrel export
├── atoms/
│   ├── aura_glass.dart         # Glass containers
│   ├── aura_button.dart        # Animated buttons
│   ├── aura_jelly_button.dart  # Jelly physics buttons
│   ├── aura_toggle.dart        # Liquid morph toggles
│   └── aura_icon.dart          # Semantic icons
└── design_system.dart          # Main barrel export
```

---

## Vibe Check Checklist

Before shipping any screen, verify:

- [ ] **Is the Black Pure?** Using `#000000` in dark mode, no blue tints
- [ ] **Is the Shadow Warm?** Light mode shadows are reddish-brown
- [ ] **Does it Resist?** Buttons sink slowly without bouncing
- [ ] **Does it Bleed?** Primary actions release a shimmer ripple on click
- [ ] **Is it Floating?** Glass containers have proper blur and borders
- [ ] **Is the Text Readable?** Proper contrast in both themes

---

## Import Reference

Single import for the entire design system:

```dart
import 'package:project_aura/core/design_system/design_system.dart';
```

This exports:
- `AuraColors`, `context.aura`
- `AuraTypography`
- `AppTheme`
- `themeModeProvider`, `ThemeModeNotifier`
- `AuraBackground`, `AuraScaffold`, `AuraAnimatedBackground`
- `AuraHaptics`, `AuraMotion`, `AuraPressable`, `PressableStyle`
- Widget extensions (`.withTension()`, `.withJelly()`, `.withIce()`, etc.)
- `AuraGlass`, `AuraGlassCard`
- `AuraButton`, `AuraButtonVariant`, `AuraIconButton`
- `AuraJellyButton`, `AuraToggle`, `AuraSwitch`
- `AuraIcon`, `AuraIconStyle`
