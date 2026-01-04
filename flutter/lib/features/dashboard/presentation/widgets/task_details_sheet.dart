import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../chat/domain/task.dart';

class TaskDetailsSheet extends ConsumerWidget {
  final SecretaryTask task;

  const TaskDetailsSheet({super.key, required this.task});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final aura = context.aura;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: aura.bgSecondary.withValues(alpha: 0.9),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        children: [
          // Drag Handle
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: aura.textSecondary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    task.title,
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: aura.textPrimary,
                    ),
                  ),
                ),
                _buildStatusBadge(task.status),
              ],
            ),
          ),

          const Divider(),

          // Task Result / Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Text(
                task.result ?? 'Processing...',
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 16,
                  height: 1.6,
                  color: aura.textPrimary.withValues(alpha: 0.8),
                ),
              ),
            ),
          ),

          // Chat Input Placeholder (for future interaction)
          Container(
            padding: const EdgeInsets.all(16),
             decoration: BoxDecoration(
              border: Border(top: BorderSide(color: aura.textSecondary.withValues(alpha: 0.1))),
            ),
            child: AuraButton.ghost(
              label: 'Reply to Secretary',
              onPressed: () {},
               icon: LucideIcons.send,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    switch (status) {
      case 'completed':
        color = AuraColors.halo;
        break;
      case 'failed':
        color = AuraColors.heartbeat;
        break;
      default:
        color = AuraColors.tether;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          fontFamily: 'Jura',
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}
