import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/design_system/design_system.dart';

class BackgroundTasksScreen extends StatelessWidget {
  const BackgroundTasksScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
            'Background Tasks',
            style: TextStyle(
              color: aura.textPrimary,
              fontFamily: 'Outfit',
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildSectionHeader('Active', context),
            const SizedBox(height: 12),
            _buildTaskItem(
              context: context,
              title: 'Syncing Calendar Events',
              subtitle: 'Google Calendar • 34% complete',
              icon: LucideIcons.refreshCw,
              isActive: true,
              index: 0,
            ),
            const SizedBox(height: 24),
            
            _buildSectionHeader('Completed Today', context),
             const SizedBox(height: 12),
             _buildTaskItem(
              context: context,
              title: 'Daily Briefing Generated',
              subtitle: '8:00 AM • Ready to view',
              icon: LucideIcons.checkCircle,
              isActive: false,
              index: 1,
            ),
             const SizedBox(height: 12),
             _buildTaskItem(
              context: context,
              title: 'Email Summary',
              subtitle: '7:45 AM • 12 emails processed',
              icon: LucideIcons.mail,
              isActive: false,
              index: 2,
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSectionHeader(String title, BuildContext context) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(
        color: AuraColors.halo,
        fontFamily: 'Jura',
        fontSize: 12,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildTaskItem({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isActive,
    required int index,
  }) {
    final aura = context.aura;

    return AuraGlass(
      padding: const EdgeInsets.all(16),
      borderRadius: BorderRadius.circular(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isActive 
                  ? AuraColors.tether.withValues(alpha: 0.2)
                  : aura.textPrimary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: isActive
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(AuraColors.tether),
                    ),
                  )
                : Icon(icon, color: aura.textPrimary.withValues(alpha: 0.7), size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: aura.textPrimary,
                    fontFamily: 'Manrope',
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: aura.textPrimary.withValues(alpha: 0.5),
                    fontFamily: 'Manrope',
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).withStaggeredEntrance(index: index);
  }
}

