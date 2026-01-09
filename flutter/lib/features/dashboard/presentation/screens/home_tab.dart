/// Dashboard - Home Tab
/// =====================
/// Home tab content showing Nucleus and Summary Sheet.
/// Fetches real data from backend using Riverpod providers.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../voice/voice_controller.dart';
import '../../data/task_repository.dart';

part 'home_tab.g.dart';

/// Provider for secretary brief data with auto-refresh
@riverpod
Future<SecretaryBrief> secretaryBrief(Ref ref) async {
  final repo = await ref.watch(taskRepositoryProvider.future);
  return repo.getSecretaryBrief();
}

/// Provider for notifications list
@riverpod
Future<List<NotificationItem>> notifications(Ref ref) async {
  final repo = await ref.watch(taskRepositoryProvider.future);
  return repo.getNotifications();
}

class HomeTab extends ConsumerStatefulWidget {
  const HomeTab({super.key});

  @override
  ConsumerState<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends ConsumerState<HomeTab> {
  @override
  Widget build(BuildContext context) {
    final briefAsync = ref.watch(secretaryBriefProvider);
    final notificationsAsync = ref.watch(notificationsProvider);
    
    // Watch voice session state
    final voiceSession = ref.watch(voiceControllerProvider);
    final isVoiceActive = voiceSession.state != VoiceState.idle;
    final nucleusVoiceState = _mapVoiceState(voiceSession.state);

    return RefreshIndicator(
      onRefresh: _refresh,
      color: AuraColors.halo,
      child: Stack(
        children: [
          Column(
            children: [
              // Nucleus area
              Expanded(
                flex: 2,
                child: Center(
                  child: AuraNucleus(
                    isActive: isVoiceActive,
                    voiceState: nucleusVoiceState,
                    size: 100,
                    onActivate: _handleSecretaryVoice,    // Short tap = secretary
                    onActiveTap: _handleNucleusTap,       // Tap while active = end turn
                    onLongPress: _handleOpenAIRealtime,   // Long press = OpenAI
                  ),
                ),
              ),

              // Summary Sheet
              Expanded(
                flex: 3,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 100),
                  child: briefAsync.when(
                    data: (brief) => _buildSummarySheet(context, brief, notificationsAsync),
                    loading: () => _buildLoadingSheet(context),
                    error: (e, _) => _buildErrorSheet(context, e),
                  ),
                ),
              ),
            ],
          ),
          
          // Voice feedback overlay
          if (isVoiceActive)
            _VoiceFeedbackOverlay(
              session: voiceSession,
              onDismiss: () => ref.read(voiceControllerProvider.notifier).stopSession(),
            ),
        ],
      ),
    );
  }

  Widget _buildSummarySheet(
    BuildContext context, 
    SecretaryBrief brief,
    AsyncValue<List<NotificationItem>> notificationsAsync,
  ) {
    final notificationCount = notificationsAsync.when(
      data: (list) => list.length,
      loading: () => brief.count,
      error: (_, __) => brief.count,
    );
    
    return AuraSummarySheet(
      title: 'Summary',
      sectionLabel: 'Secretary Brief',
      content: brief.brief,
      stats: [
        SummaryStatItem(
          label: 'Tasks',
          value: brief.items.where((n) => n.type == 'task').length,
          onTap: () => _showTasksSheet(context, brief.items),
        ),
        SummaryStatItem(
          label: 'Unread',
          value: notificationCount,
          valueColor: notificationCount > 0 ? AuraColors.tether : null,
          onTap: () => _showUnreadSheet(context, notificationsAsync),
        ),
      ],
      onExpand: () => context.push('/background-tasks'),
    );
  }

  Widget _buildLoadingSheet(BuildContext context) {
    return AuraSummarySheet(
      title: 'Summary',
      sectionLabel: 'Loading...',
      content: 'Fetching your secretary brief...',
      stats: [
        SummaryStatItem(label: 'Tasks', value: 0, onTap: () {}),
        SummaryStatItem(label: 'Unread', value: 0, onTap: () {}),
      ],
      onExpand: () {},
    );
  }

  Widget _buildErrorSheet(BuildContext context, Object error) {
    return AuraSummarySheet(
      title: 'Summary',
      sectionLabel: 'Connection Issue',
      content: 'Unable to connect to the server. Pull down to retry.',
      stats: [
        SummaryStatItem(label: 'Tasks', value: 0, onTap: () {}),
        SummaryStatItem(label: 'Unread', value: 0, onTap: () {}),
      ],
      onExpand: () {},
    );
  }

  Future<void> _refresh() async {
    ref.invalidate(secretaryBriefProvider);
    ref.invalidate(notificationsProvider);
    // Wait for the provider to refresh
    await ref.read(secretaryBriefProvider.future);
  }

  void _showTasksSheet(BuildContext context, List<NotificationItem> items) {
    final tasks = items.where((n) => n.type == 'task' || n.type == 'background').toList();
    
    showAuraListBottomSheet<void, NotificationItem>(
      context: context,
      title: 'Processing Tasks',
      icon: LucideIcons.loader,
      items: tasks,
      emptyMessage: 'No active tasks',
      itemBuilder: (dynamic item, int index) => _TaskItem(item: item as NotificationItem),
    );
  }

  void _showUnreadSheet(BuildContext context, AsyncValue<List<NotificationItem>> notificationsAsync) {
    final notifications = notificationsAsync.when(
      data: (list) => list,
      loading: () => <NotificationItem>[],
      error: (_, __) => <NotificationItem>[],
    );
    
    showAuraListBottomSheet<void, NotificationItem>(
      context: context,
      title: 'Notifications',
      icon: LucideIcons.bell,
      items: notifications,
      emptyMessage: 'All caught up!',
      itemBuilder: (dynamic item, int index) {
        final notification = item as NotificationItem;
        return _NotificationItemWidget(
          item: notification,
          onMarkRead: () => _markAsRead(notification.id),
        );
      },
    );
  }

  Future<void> _markAsRead(String taskId) async {
    try {
      final repo = await ref.read(taskRepositoryProvider.future);
      await repo.markNotificationRead(taskId);
      ref.invalidate(notificationsProvider);
      ref.invalidate(secretaryBriefProvider);
    } catch (e) {
      debugPrint('Failed to mark as read: $e');
    }
  }

  /// Short tap = Start backend secretary voice protocol
  void _handleSecretaryVoice() {
    ref.read(voiceControllerProvider.notifier).startSession();
  }

  /// Long press = Start OpenAI Realtime API (premium mode)
  void _handleOpenAIRealtime() {
    // TODO: Implement OpenAI Realtime API integration
    // For now, show a snackbar indicating this feature
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('OpenAI Realtime coming soon! Using secretary voice...'),
        backgroundColor: AuraColors.halo,
        duration: const Duration(seconds: 2),
      ),
    );
    // Fall back to secretary voice for now
    _handleSecretaryVoice();
  }

  /// Tap while active = end turn or stop session
  void _handleNucleusTap() {
    final voiceState = ref.read(voiceControllerProvider);
    
    if (voiceState.state == VoiceState.listening) {
      // End turn - trigger STT
      ref.read(voiceControllerProvider.notifier).endTurn();
    } else if (voiceState.state != VoiceState.idle) {
      // Stop session
      ref.read(voiceControllerProvider.notifier).stopSession();
    }
  }

  /// Map VoiceController state to Nucleus visual state
  NucleusVoiceState _mapVoiceState(VoiceState state) {
    switch (state) {
      case VoiceState.listening:
        return NucleusVoiceState.whisper;
      case VoiceState.speaking:
        return NucleusVoiceState.loud;
      case VoiceState.transcribing:
      case VoiceState.processing:
        return NucleusVoiceState.whisper;
      default:
        return NucleusVoiceState.silence;
    }
  }
}

/// Task item widget for bottom sheet
class _TaskItem extends StatelessWidget {
  final NotificationItem item;

  const _TaskItem({required this.item});

  @override
  Widget build(BuildContext context) {
    final aura = context.aura;

    return AuraSheetItem(
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AuraColors.halo.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(LucideIcons.loader, color: AuraColors.halo, size: 18),
      ),
      title: item.title,
      subtitle: item.description,
      trailing: Text(
        item.time,
        style: TextStyle(
          fontSize: 12,
          color: aura.textPrimary.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}

/// Notification item widget for bottom sheet
class _NotificationItemWidget extends StatelessWidget {
  final NotificationItem item;
  final VoidCallback? onMarkRead;

  const _NotificationItemWidget({
    required this.item,
    this.onMarkRead,
  });

  @override
  Widget build(BuildContext context) {
    final aura = context.aura;

    final (IconData icon, Color color) = switch (item.type) {
      'completed' || 'success' => (LucideIcons.checkCircle, AuraColors.tether),
      'reminder' || 'calendar' => (LucideIcons.clock, AuraColors.halo),
      'message' || 'chat' => (LucideIcons.messageCircle, AuraColors.heartbeat),
      'error' || 'failed' => (LucideIcons.alertCircle, AuraColors.heartbeat),
      _ => (LucideIcons.bell, aura.textPrimary),
    };

    return GestureDetector(
      onTap: onMarkRead,
      child: AuraSheetItem(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        title: item.title,
        subtitle: '${item.description} • ${item.time}',
        trailing: item.isRead
            ? null
            : Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
      ),
    );
  }
}

/// Voice feedback overlay showing transcription and status
class _VoiceFeedbackOverlay extends StatelessWidget {
  final VoiceSession session;
  final VoidCallback onDismiss;

  const _VoiceFeedbackOverlay({
    required this.session,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final aura = context.aura;

    return Positioned(
      left: 16,
      right: 16,
      bottom: 120,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _getStateColor().withValues(alpha: 0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: _getStateColor().withValues(alpha: 0.2),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Status icon and text
            Row(
              children: [
                _buildStatusIcon(),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getStatusText(),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: aura.textPrimary,
                        ),
                      ),
                      if (session.transcription != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '"${session.transcription}"',
                            style: TextStyle(
                              fontSize: 13,
                              fontStyle: FontStyle.italic,
                              color: aura.textPrimary.withValues(alpha: 0.7),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      if (session.errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            session.errorMessage!,
                            style: TextStyle(
                              fontSize: 12,
                              color: AuraColors.heartbeat,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onDismiss,
                  icon: Icon(
                    LucideIcons.x,
                    size: 20,
                    color: aura.textPrimary.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIcon() {
    final color = _getStateColor();
    final icon = _getStateIcon();

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }

  Color _getStateColor() {
    switch (session.state) {
      case VoiceState.listening:
        return AuraColors.tether;
      case VoiceState.transcribing:
      case VoiceState.processing:
        return AuraColors.halo;
      case VoiceState.speaking:
        return AuraColors.heartbeat;
      case VoiceState.error:
        return AuraColors.heartbeat;
      default:
        return AuraColors.halo;
    }
  }

  IconData _getStateIcon() {
    switch (session.state) {
      case VoiceState.connecting:
        return LucideIcons.wifi;
      case VoiceState.listening:
        return LucideIcons.mic;
      case VoiceState.transcribing:
        return LucideIcons.fileText;
      case VoiceState.processing:
        return LucideIcons.brain;
      case VoiceState.speaking:
        return LucideIcons.volume2;
      case VoiceState.error:
        return LucideIcons.alertCircle;
      default:
        return LucideIcons.mic;
    }
  }

  String _getStatusText() {
    switch (session.state) {
      case VoiceState.connecting:
        return 'Connecting...';
      case VoiceState.listening:
        return 'Listening... Tap when done';
      case VoiceState.transcribing:
        return 'Transcribing...';
      case VoiceState.processing:
        return 'Thinking...';
      case VoiceState.speaking:
        return 'Speaking...';
      case VoiceState.error:
        return 'Error';
      default:
        return 'Ready';
    }
  }
}

