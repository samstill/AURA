import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/design_system/design_system.dart';

class ToolsScreen extends StatelessWidget {
  const ToolsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final aura = context.aura;

    // Using AuraOrbBackground instead of custom implementation
    return AuraOrbBackground(
      showBottomAccent: true, // Matches the bottom gradient line from previous design
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            // Header Title and Profile
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Tools',
                    style: TextStyle(
                      color: aura.textPrimary, // Consistent with Aura text
                      fontSize: 48,
                      fontFamily: 'Outfit',
                      fontWeight: FontWeight.w600,
                      height: 1.10,
                      letterSpacing: -0.96,
                    ),
                  ),
                  // Profile Avatar
                   GestureDetector(
                      onTap: () {
                        context.push('/profile'); // Points to SettingsScreen now
                      },
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: const Color(0xFF2A2A2A),
                          shape: BoxShape.circle,
                          border: Border.all(color: AuraColors.heartbeat.withValues(alpha: 0.3), width: 1.5),
                          image: const DecorationImage(
                            image: NetworkImage('https://i.pravatar.cc/150?img=11'),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Search Bar Row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: AuraGlass(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      height: 48,
                      borderRadius: BorderRadius.circular(41),
                      child: Row(
                        children: [
                          Icon(
                            LucideIcons.search,
                            color: aura.textPrimary.withValues(alpha: 0.4),
                            size: 18,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Search connections...',
                            style: TextStyle(
                              color: aura.textPrimary.withValues(alpha: 0.5),
                              fontSize: 14,
                              fontFamily: 'Manrope',
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Add Custom Tool Button - Glassmorphic
                  AuraGlass(
                    width: 48,
                    height: 48,
                    padding: EdgeInsets.zero,
                    borderRadius: BorderRadius.circular(41),
                    child: Center(
                      child: Icon(
                        LucideIcons.plus,
                        color: aura.textPrimary,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Connections List
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                child: Column(
                  children: [
                    const _ConnectionCard(
                      icon: LucideIcons.calendar,
                      title: 'Google Calendar',
                      isConnected: true,
                      showSettings: true,
                      index: 0,
                    ),
                    const SizedBox(height: 12),
                    const _ConnectionCard(
                      icon: LucideIcons.fileText, // Notion substitute
                      title: 'Notion',
                      isConnected: false,
                      connectColor: AuraColors.heartbeat, // Using aura color
                      index: 1,
                    ),
                    const SizedBox(height: 12),
                    const _ConnectionCard(
                      icon: LucideIcons.circleDot, // Linear substitute
                      title: 'Linear',
                      isConnected: false,
                      connectColor: AuraColors.heartbeat,
                      index: 2,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConnectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool isConnected;
  final Color? connectColor;
  final bool showSettings;
  final int index;

  const _ConnectionCard({
    required this.icon,
    required this.title,
    required this.isConnected,
    this.connectColor,
    this.showSettings = false,
    this.index = 0,
  });

  @override
  Widget build(BuildContext context) {
    final aura = context.aura;

    return AuraGlass(
      height: 78,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      borderRadius: BorderRadius.circular(16),
      onTap: isConnected ? null : () {}, // Make connect cards tappable
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Icon and Title
          Expanded(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: ShapeDecoration(
                    color: aura.textPrimary.withValues(alpha: 0.10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16.40),
                    ),
                  ),
                  child: Center(
                    child: Icon(icon, color: aura.textPrimary, size: 20),
                  ),
                ),
                const SizedBox(width: 16),
                Flexible(
                  child: Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: aura.textPrimary,
                      fontSize: 18,
                      fontFamily: 'Outfit',
                      fontWeight: FontWeight.w400,
                      height: 1.56,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Status / Button
          if (isConnected)
            _buildConnectedBadge(context)
          else
            _buildConnectButton(context),
        ],
      ),
    );
  }

  Widget _buildConnectedBadge(BuildContext context) {
    final aura = context.aura;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: ShapeDecoration(
            color: AuraColors.tether.withValues(alpha: 0.1),
            shape: RoundedRectangleBorder(
              side: BorderSide(
                width: 1.24,
                color: AuraColors.tether.withValues(alpha: 0.2),
              ),
              borderRadius: BorderRadius.circular(41),
            ),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.check, size: 12, color: AuraColors.tether),
              SizedBox(width: 8),
              Text(
                'CONNECTED',
                style: TextStyle(
                  color: AuraColors.tether,
                  fontSize: 12,
                  fontFamily: 'Arimo',
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0.30,
                ),
              ),
            ],
          ),
        ),
        if (showSettings) ...[
          const SizedBox(width: 12),
          Icon(
            LucideIcons.settings,
            color: aura.textPrimary.withValues(alpha: 0.5),
            size: 20,
          ),
        ],
      ],
    );
  }

  Widget _buildConnectButton(BuildContext context) {
    // Using AuraButton but small/compact
    return Container(
      width: 101,
      height: 36,
      decoration: ShapeDecoration(
        color: connectColor ?? AuraColors.heartbeat,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(41),
        ),
        shadows: [
          BoxShadow(
            color: (connectColor ?? AuraColors.heartbeat).withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: const Center(
        child: Text(
          'Connect',
          style: TextStyle(
            color: Colors.white, // Button text should generally remain white on primary action colors
            fontSize: 14,
            fontFamily: 'Arimo',
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
