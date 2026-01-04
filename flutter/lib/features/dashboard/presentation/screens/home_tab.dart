/// Dashboard - Home Tab
/// =====================
/// Home tab content showing Nucleus and Summary Sheet.
/// This is displayed inside the DashboardShell.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/design_system/design_system.dart';

class HomeTab extends ConsumerStatefulWidget {
  const HomeTab({super.key});

  @override
  ConsumerState<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends ConsumerState<HomeTab> {
  bool _isNucleusActive = false;
  NucleusVoiceState _voiceState = NucleusVoiceState.silence;

  // Mock data for demo - Secretary background tasks in progress
  final List<Map<String, dynamic>> _processingTasks = [
    {
      'title': 'Summarizing email inbox',
      'status': 'Processing 34 emails...',
      'progress': 0.65,
      'icon': 'mail',
    },
    {
      'title': 'Syncing calendar events',
      'status': 'Fetching from Google Calendar',
      'progress': 0.8,
      'icon': 'calendar',
    },
    {
      'title': 'Preparing daily briefing',
      'status': 'Analyzing priorities...',
      'progress': 0.25,
      'icon': 'clipboard',
    },
  ];

  // Mock data for demo - Notifications (including completed secretary tasks)
  final List<Map<String, dynamic>> _unreadNotifications = [
    {
      'title': 'Email summary ready',
      'description': '12 important emails flagged',
      'time': '2 min ago',
      'type': 'completed',
    },
    {
      'title': 'Meeting reminder',
      'description': 'Design Review in 30 minutes',
      'time': '5 min ago',
      'type': 'reminder',
    },
    {
      'title': 'Task completed',
      'description': 'Calendar sync finished successfully',
      'time': '15 min ago',
      'type': 'completed',
    },
    {
      'title': 'New message from Sarah',
      'description': 'Regarding the Q4 proposal',
      'time': '1 hour ago',
      'type': 'message',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Nucleus area
        Expanded(
          flex: 2,
          child: Center(
            child: AuraNucleus(
              isActive: _isNucleusActive,
              voiceState: _voiceState,
              size: 100,
              onActivate: _handleNucleusActivate,
              onTap: _handleNucleusTap,
            ),
          ),
        ),

        // Summary Sheet
        Expanded(
          flex: 3,
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 100),
            child: AuraSummarySheet(
              title: 'Summary',
              sectionLabel: 'Analysis',
              content:
                  'The silence has been observed. No active disturbances detected in the local field. The Nucleus remains in a state of dormant waiting.',
              stats: [
                SummaryStatItem(
                  label: 'Tasks',
                  value: _processingTasks.length,
                  onTap: () => _showTasksSheet(context),
                ),
                SummaryStatItem(
                  label: 'Unread',
                  value: _unreadNotifications.length,
                  valueColor: AuraColors.tether,
                  onTap: () => _showUnreadSheet(context),
                ),
              ],
              onExpand: () => context.push('/background-tasks'),
            ),
          ),
        ),
      ],
    );
  }

  void _showTasksSheet(BuildContext context) {
    showAuraListBottomSheet(
      context: context,
      title: 'Processing Tasks',
      icon: LucideIcons.loader,
      items: _processingTasks,
      emptyMessage: 'No active tasks',
      itemBuilder: (item, index) => _ProcessingTaskItem(
        title: item['title'],
        status: item['status'],
        progress: item['progress'],
        iconType: item['icon'],
      ),
    );
  }

  void _showUnreadSheet(BuildContext context) {
    showAuraListBottomSheet(
      context: context,
      title: 'Notifications',
      icon: LucideIcons.bell,
      items: _unreadNotifications,
      emptyMessage: 'All caught up!',
      itemBuilder: (item, index) => _NotificationItem(
        title: item['title'],
        description: item['description'],
        time: item['time'],
        type: item['type'],
      ),
    );
  }

  void _handleNucleusActivate() {
    setState(() {
      _isNucleusActive = true;
      _voiceState = NucleusVoiceState.silence;
    });
    _simulateVoiceActivity();
  }

  void _handleNucleusTap() {
    setState(() {
      _isNucleusActive = false;
      _voiceState = NucleusVoiceState.silence;
    });
  }

  void _simulateVoiceActivity() async {
    if (!_isNucleusActive) return;

    await Future.delayed(AuraMotion.dramatic);
    if (!mounted || !_isNucleusActive) return;
    setState(() => _voiceState = NucleusVoiceState.whisper);

    await Future.delayed(const Duration(seconds: 2));
    if (!mounted || !_isNucleusActive) return;
    setState(() => _voiceState = NucleusVoiceState.loud);

    await Future.delayed(AuraMotion.deliberate);
    if (!mounted || !_isNucleusActive) return;
    setState(() => _voiceState = NucleusVoiceState.whisper);

    await Future.delayed(const Duration(seconds: 2));
    if (!mounted || !_isNucleusActive) return;
    setState(() => _voiceState = NucleusVoiceState.silence);
  }
}

// Processing task item widget for bottom sheet
class _ProcessingTaskItem extends StatelessWidget {
  final String title;
  final String status;
  final double progress;
  final String iconType;

  const _ProcessingTaskItem({
    required this.title,
    required this.status,
    required this.progress,
    required this.iconType,
  });

  @override
  Widget build(BuildContext context) {
    final aura = context.aura;
    final taskIcon = switch (iconType) {
      'mail' => LucideIcons.mail,
      'calendar' => LucideIcons.calendar,
      'clipboard' => LucideIcons.clipboardList,
      _ => LucideIcons.loader,
    };

    return AuraSheetItem(
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AuraColors.halo.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(taskIcon, color: AuraColors.halo, size: 18),
      ),
      title: title,
      subtitle: status,
      trailing: SizedBox(
        width: 40,
        height: 40,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CircularProgressIndicator(
              value: progress,
              strokeWidth: 3,
              backgroundColor: aura.textPrimary.withValues(alpha: 0.1),
              valueColor: const AlwaysStoppedAnimation(AuraColors.halo),
            ),
            Text(
              '${(progress * 100).toInt()}%',
              style: TextStyle(
                fontFamily: 'Jura',
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: aura.textPrimary.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Notification item widget for bottom sheet
class _NotificationItem extends StatelessWidget {
  final String title;
  final String description;
  final String time;
  final String type;

  const _NotificationItem({
    required this.title,
    required this.description,
    required this.time,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    final aura = context.aura;
    
    final (IconData icon, Color color) = switch (type) {
      'completed' => (LucideIcons.checkCircle, AuraColors.tether),
      'reminder' => (LucideIcons.clock, AuraColors.halo),
      'message' => (LucideIcons.messageCircle, AuraColors.heartbeat),
      _ => (LucideIcons.bell, aura.textPrimary),
    };

    return AuraSheetItem(
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
      title: title,
      subtitle: '$description • $time',
      trailing: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

