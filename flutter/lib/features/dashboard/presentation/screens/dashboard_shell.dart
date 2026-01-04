/// Dashboard - Shell
/// ==================
/// Main navigation shell that wraps all dashboard screens.
/// Uses IndexedStack to persist tab state and keep bottom nav visible.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/design_system/design_system.dart';
import 'home_tab.dart';
import 'tools_screen.dart';

/// Main dashboard shell with persistent bottom navigation
class DashboardShell extends ConsumerStatefulWidget {
  const DashboardShell({super.key});

  @override
  ConsumerState<DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends ConsumerState<DashboardShell> {
  int _selectedIndex = 0;

  /// List of navigation items - easily extendable for future tabs
  static const List<AuraNavItem> _navItems = [
    AuraNavItem(icon: LucideIcons.home, label: 'Home'),
    AuraNavItem(icon: LucideIcons.layoutGrid, label: 'Tools'),
    // Add more tabs here as needed:
    // AuraNavItem(icon: LucideIcons.calendar, label: 'Calendar'),
    // AuraNavItem(icon: LucideIcons.messageCircle, label: 'Chat'),
  ];

  /// List of tab pages - must match _navItems order
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = const [
      HomeTab(),
      ToolsScreen(),
      // Add more pages here as needed
    ];
  }

  void _onTabChanged(int index) {
    if (index != _selectedIndex) {
      setState(() => _selectedIndex = index);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuraOrbBackground(
      showBottomAccent: false,
      child: Stack(
        children: [
          // Page content with IndexedStack to preserve state
          SafeArea(
            bottom: false,
            child: IndexedStack(
              index: _selectedIndex,
              children: _pages,
            ),
          ),

          // Floating Bottom Navigation - always visible
          AuraBottomNav(
            items: _navItems,
            selectedIndex: _selectedIndex,
            onTabChanged: _onTabChanged,
          ),
        ],
      ),
    );
  }
}
