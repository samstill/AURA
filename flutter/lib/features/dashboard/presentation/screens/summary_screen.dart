/// Dashboard - Summary Screen
/// ============================
/// Full summary screen accessible from expand button on summary sheet.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../chat/domain/task.dart';
import '../../data/task_repository.dart';
import '../widgets/task_details_sheet.dart';

class SummaryScreen extends ConsumerStatefulWidget {
  const SummaryScreen({super.key});

  @override
  ConsumerState<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends ConsumerState<SummaryScreen> {
  late Future<List<SecretaryTask>> _tasksFuture;

  @override
  void initState() {
    super.initState();
    _refreshTasks();
  }

  Future<void> _refreshTasks() async {
    final repo = await ref.read(taskRepositoryProvider.future);
    setState(() {
      _tasksFuture = repo.getTasks();
    });
  }

  @override
  Widget build(BuildContext context) {
    final aura = context.aura;

    return AuraOrbBackground(
      showBottomAccent: false,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Back button header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  AuraJellyButton(
                    icon: const Icon(LucideIcons.arrowLeft),
                    onTap: () => Navigator.of(context).pop(),
                    tooltip: 'Back',
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'Summary',
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: aura.textPrimary,
                    ),
                  ),
                ],
              ),
            ),

            // Task List
            Expanded(
              child: FutureBuilder<List<SecretaryTask>>(
                future: _tasksFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Failed to load tasks',
                        style: TextStyle(color: aura.textSecondary),
                      ),
                    );
                  }

                  final tasks = snapshot.data ?? [];
                  if (tasks.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(LucideIcons.checkCircle, size: 48, color: aura.textSecondary.withValues(alpha: 0.5)),
                          const SizedBox(height: 16),
                          Text(
                            'All caught up!',
                            style: TextStyle(
                              fontFamily: 'Manrope',
                              fontSize: 16,
                              color: aura.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: tasks.length,
                    itemBuilder: (context, index) {
                      final task = tasks[index];
                      return _buildTaskItem(context, task, aura);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskItem(BuildContext context, SecretaryTask task, AuraColors aura) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showTaskDetails(task),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: aura.bgSecondary.withValues(alpha: 0.6),
             borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: task.isRead 
                  ? aura.textSecondary.withValues(alpha: 0.1) 
                  : AuraColors.tether.withValues(alpha: 0.5),
            ),
          ),
          child: Row(
            children: [
              // Icon based on status
              Icon(
                task.status == 'completed' ? LucideIcons.checkCircle2 : LucideIcons.loader2,
                color: task.status == 'completed' ? AuraColors.halo : AuraColors.tether,
                size: 20,
              ),
              const SizedBox(width: 16),
              
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 16,
                        fontWeight: task.isRead ? FontWeight.normal : FontWeight.w600,
                        color: aura.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      task.status.toUpperCase(),
                      style: TextStyle(
                        fontFamily: 'Jura',
                        fontSize: 10,
                        color: aura.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              
              if (!task.isRead)
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AuraColors.tether,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTaskDetails(SecretaryTask task) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TaskDetailsSheet(task: task),
    ).then((_) {
      // Refresh list when resuming (to update read status if optimized)
      // Ideally we should update local state optimistically
      if (!task.isRead) {
        ref.read(taskRepositoryProvider.future).then((repo) {
          repo.markAsRead(task.id);
          _refreshTasks();
        });
      }
    });
  }
}
