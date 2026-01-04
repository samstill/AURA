import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../../core/router/app_router.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final aura = context.aura;

    return AuraOrbBackground(
      showBottomAccent: false,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(LucideIcons.arrowLeft, color: aura.textPrimary),
            onPressed: () => context.pop(),
          ),
          title: Text(
            'Settings',
            style: TextStyle(
              color: aura.textPrimary,
              fontFamily: 'Outfit',
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            const SizedBox(height: 24),
            // Profile Section
            Center(
              child: Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AuraColors.heartbeat.withValues(alpha: 0.3),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 50,
                      backgroundColor: AuraColors.heartbeat.withValues(alpha: 0.1),
                      child: const CircleAvatar(
                        radius: 48,
                        backgroundImage: NetworkImage('https://i.pravatar.cc/150?img=11'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'User Name',
                    style: TextStyle(
                      color: aura.textPrimary,
                      fontFamily: 'Outfit',
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'user@encresa.com',
                    style: TextStyle(
                      color: aura.textPrimary.withValues(alpha: 0.5),
                      fontFamily: 'Manrope',
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 48),

            // Settings Menu
            _buildSettingsItem(
              context,
              icon: LucideIcons.bot,
              title: 'Edit Secretary Name',
              onTap: () => context.push('/settings/secretary'),
            ),
            const SizedBox(height: 12),
            _buildSettingsItem(
              context,
              icon: LucideIcons.user,
              title: 'Account Settings',
              onTap: () => context.push('/settings/account'),
            ),
            const SizedBox(height: 12),
            _buildSettingsItem(
              context,
              icon: LucideIcons.settings,
              title: 'App Settings',
              onTap: () => context.push('/settings/app'),
            ),
            const SizedBox(height: 48),

            // Log Out
            AuraGlass(
              padding: const EdgeInsets.all(4),
              borderRadius: BorderRadius.circular(16),
              child: AuraButton(
                label: 'Sign Out',
                icon: LucideIcons.logOut,
                variant: AuraButtonVariant.heartbeat,
                onPressed: () {
                  AuthChangeNotifier.instance.setAuthenticated(false);
                },
              ),
            ),
             const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsItem(BuildContext context, {required IconData icon, required String title, required VoidCallback onTap}) {
    final aura = context.aura;

    return AuraGlass(
      padding: EdgeInsets.zero,
      borderRadius: BorderRadius.circular(16),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: aura.textPrimary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: aura.textPrimary, size: 20),
        ),
        title: Text(
          title,
          style: TextStyle(
             color: aura.textPrimary,
             fontFamily: 'Manrope',
             fontSize: 16,
             fontWeight: FontWeight.w500,
          ),
        ),
        trailing: Icon(LucideIcons.chevronRight, color: aura.textPrimary.withValues(alpha: 0.5), size: 16),
      ),
    );
  }
}
