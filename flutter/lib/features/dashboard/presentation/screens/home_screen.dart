/// Dashboard - Home Screen
/// ========================
/// Main entry screen for Project Aura
/// Implements the "Tactical Implementation of Desire" design philosophy.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/auth/presentation/controllers/controllers.dart';
import '../../../../core/design_system/design_system.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final challenge = ref.watch(currentChallengeProvider);
    final pendingUser = challenge?.pendingUser;
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark ||
        (themeMode == ThemeMode.system &&
            MediaQuery.of(context).platformBrightness == Brightness.dark);

    return AuraScaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // App Bar with Jelly icon buttons
            SliverAppBar.large(
              backgroundColor: Colors.transparent,
              title: Text(
                'Project Aura',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              centerTitle: false,
              actions: [
                // Theme Toggle with Liquid Morph physics
                AuraToggle(
                  value: isDark,
                  onChanged: (_) =>
                      ref.read(themeModeProvider.notifier).toggle(),
                ),
                const SizedBox(width: 12),
                // Jelly Button for Notifications
                AuraJellyButton(
                  icon: AuraIcon(LucideIcons.bell),
                  onTap: () => _showComingSoon(context, 'Notifications'),
                  tooltip: 'Notifications',
                ),
                const SizedBox(width: 4),
                // Jelly Button for Settings
                AuraJellyButton(
                  icon: AuraIcon(LucideIcons.settings),
                  onTap: () => _showComingSoon(context, 'Settings'),
                  tooltip: 'Settings',
                ),
                const SizedBox(width: 12),
              ],
            ),

            // Content
            SliverPadding(
              padding: const EdgeInsets.all(20),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Welcome Card with entrance animation
                  _WelcomeCard(userName: pendingUser).withIce(),
                  const SizedBox(height: 24),

                  // Status Card
                  const _StatusCard().withStaggeredEntrance(index: 1),
                  const SizedBox(height: 24),

                  // Quick Actions Header
                  Text(
                    'Quick Actions',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ).withStaggeredEntrance(index: 2),
                  const SizedBox(height: 12),

                  // Quick Actions with Jelly buttons
                  const _QuickActionsRow().withStaggeredEntrance(index: 3),
                  const SizedBox(height: 24),

                  // AI Assistant Card
                  const _AIAssistantCard().withStaggeredEntrance(index: 4),
                  const SizedBox(height: 24),

                  // Preferences Section
                  _PreferencesSection(isDark: isDark, ref: ref)
                      .withStaggeredEntrance(index: 5),
                  const SizedBox(height: 24),

                  // Sign Out Button
                  Center(
                    child: AuraButton.ghost(
                      label: 'Sign Out',
                      icon: LucideIcons.logOut,
                      onPressed: () => _showLogoutDialog(context, ref),
                    ),
                  ).withStaggeredEntrance(index: 6),
                  const SizedBox(height: 40),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature feature coming soon!'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: context.aura.bgSecondary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.aura.bgSecondary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(color: ctx.aura.textSecondary),
            ),
          ),
          AuraButton.heartbeat(
            label: 'Sign Out',
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(authControllerProvider.notifier).logout();
              if (context.mounted) {
                context.go('/login');
              }
            },
          ),
        ],
      ),
    );
  }
}

/// Preferences section with theme toggle
class _PreferencesSection extends StatelessWidget {
  final bool isDark;
  final WidgetRef ref;

  const _PreferencesSection({required this.isDark, required this.ref});

  @override
  Widget build(BuildContext context) {
    return AuraGlass(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Preferences',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              AuraIcon(
                isDark ? LucideIcons.moon : LucideIcons.sun,
                style: AuraIconStyle.halo,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isDark ? 'The Void' : 'The Mirage',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    Text(
                      isDark ? 'Dark theme active' : 'Light theme active',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: context.aura.textSecondary,
                          ),
                    ),
                  ],
                ),
              ),
              AuraToggle(
                value: isDark,
                onChanged: (_) => ref.read(themeModeProvider.notifier).toggle(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Welcome card with gradient and user greeting
class _WelcomeCard extends StatelessWidget {
  final String? userName;

  const _WelcomeCard({this.userName});

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context) {
    final displayName = userName ?? 'User';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AuraColors.heartbeat, AuraColors.tether],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AuraColors.heartbeat.withOpacity(0.4),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      _getGreeting(),
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Colors.white.withOpacity(0.8),
                          ),
                    ),
                    const SizedBox(width: 8),
                    const Text('👋', style: TextStyle(fontSize: 20)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  displayName,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your AI Secretary is ready to assist',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withOpacity(0.7),
                      ),
                ),
              ],
            ),
          ),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Authentication status card
class _StatusCard extends StatelessWidget {
  const _StatusCard();

  @override
  Widget build(BuildContext context) {
    final aura = context.aura;

    return AuraGlass(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              LucideIcons.shieldCheck,
              color: Colors.green.shade400,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Authenticated',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade400,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Connected to Authentik IDP',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: aura.textSecondary,
                      ),
                ),
              ],
            ),
          ),
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: Colors.green,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.green.withOpacity(0.5),
                  blurRadius: 8,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Quick actions row with Jelly buttons
class _QuickActionsRow extends StatelessWidget {
  const _QuickActionsRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _QuickActionJelly(
          icon: LucideIcons.messageCircle,
          label: 'Chat',
          color: AuraColors.heartbeat,
          onTap: () => _showComingSoon(context, 'Chat'),
        ),
        _QuickActionJelly(
          icon: LucideIcons.calendar,
          label: 'Calendar',
          color: AuraColors.tether,
          onTap: () => _showComingSoon(context, 'Calendar'),
        ),
        _QuickActionJelly(
          icon: LucideIcons.checkSquare,
          label: 'Tasks',
          color: AuraColors.halo,
          onTap: () => _showComingSoon(context, 'Tasks'),
        ),
        _QuickActionJelly(
          icon: LucideIcons.folder,
          label: 'Files',
          color: context.aura.textPrimary,
          onTap: () => _showComingSoon(context, 'Files'),
        ),
      ],
    );
  }

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature feature coming soon!'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

/// Individual quick action with Jelly physics
class _QuickActionJelly extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionJelly({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AuraJellyButton(
          icon: Icon(icon, size: 28, color: color),
          onTap: onTap,
          tooltip: label,
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: color,
              ),
        ),
      ],
    );
  }
}

/// AI Assistant promotional card
class _AIAssistantCard extends StatelessWidget {
  const _AIAssistantCard();

  @override
  Widget build(BuildContext context) {
    return AuraGlassCard(
      header: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AuraColors.halo, AuraColors.tether],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              LucideIcons.sparkles,
              color: Colors.black,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI Assistant',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                Text(
                  'Powered by advanced AI',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.aura.textSecondary,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Text(
        'Ask me anything! I can help you manage your calendar, draft emails, summarize documents, and more.',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: context.aura.textSecondary,
            ),
      ),
      footer: AuraButton.heartbeat(
        label: 'Start Conversation',
        icon: LucideIcons.messageCircle,
        fullWidth: true,
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('AI Chat feature coming soon!'),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        },
      ),
    );
  }
}
