/// Dashboard - Home Screen
/// ========================
/// Main entry screen for Project Aura
/// Features the Nucleus voice orb, Summary Sheet, and floating BottomNav.
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/auth/presentation/controllers/controllers.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../../core/api/voice_service.dart';
import '../../data/task_repository.dart';
import '../../../../core/router/app_router.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _selectedNavIndex = 0;
  bool _isNucleusActive = false;
  NucleusVoiceState _voiceState = NucleusVoiceState.silence;
  Map<String, int> _taskStats = {'unread': 0, 'total': 0};
  String _summaryText = 'Analyzing background activities...';
  StreamSubscription? _connectionSubscription;

  @override
  void initState() {
    super.initState();
    _loadStats();
    // Listen to voice state
    ref.read(voiceServiceProvider).stateStream.listen((state) {
      if (!mounted) return;
      setState(() {
        switch (state) {
          case VoiceState.listening:
            _voiceState = NucleusVoiceState.whisper; // listening -> whisper
            break;
          case VoiceState.processing:
             _voiceState = NucleusVoiceState.silence; 
            break;
           case VoiceState.speaking:
            _voiceState = NucleusVoiceState.loud;
            break;
          case VoiceState.silence:
          default:
            _voiceState = NucleusVoiceState.silence;
            _isNucleusActive = false; // Auto-deactivate on silence
            break;
        }
      });
    });
    // Listen to connection state
    _connectionSubscription = ref.read(voiceServiceProvider).connectionStream.listen((state) {
      if (!mounted) return;
      
      String? message;
      Color? color;

      setState(() {
        switch (state) {
          case VoiceConnectionState.connecting:
            message = 'Connecting to Secretary...';
            color = AuraColors.tether;
            _isNucleusActive = true;
            // Use silence or a specific connecting animation if available
            _voiceState = NucleusVoiceState.silence; 
            break;
          case VoiceConnectionState.connected:
            message = 'Connected';
            color = AuraColors.halo; // Cyan/Success
            _voiceState = NucleusVoiceState.whisper;
            break;
          case VoiceConnectionState.error:
            message = 'Connection Failed';
            color = AuraColors.heartbeat;
            _isNucleusActive = false;
            _voiceState = NucleusVoiceState.silence;
            break;
          case VoiceConnectionState.disconnected:
            _isNucleusActive = false;
            _voiceState = NucleusVoiceState.silence;
            break;
        }
      });

      if (message != null && mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message!),
            backgroundColor: context.aura.bgSecondary,
            behavior: SnackBarBehavior.floating,
             shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: color ?? context.aura.textSecondary, width: 1),
            ),
            duration: const Duration(seconds: 2),
             action: state == VoiceConnectionState.error 
                ? SnackBarAction(label: 'Retry', onPressed: _handleNucleusActivate)
                : null,
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _connectionSubscription?.cancel();
    super.dispose();
  }




  Future<void> _loadStats() async {
    try {
      final repo = await ref.read(taskRepositoryProvider.future);
      final stats = await repo.getSummary();
      
      // Only fetch generative summary if there are tasks
      String summary = "The silence has been observed. No active disturbances detected.";
      if ((stats['total'] ?? 0) > 0) {
        summary = await repo.getTaskOverview();
      }

      if (mounted) {
        setState(() {
          _taskStats = stats;
          _summaryText = summary;
        });
      }
    } catch (e) {
      debugPrint('Failed to load stats: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuraOrbBackground(
      showBottomAccent: false,
      child: Stack(
        children: [
          // Main content
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                // Nucleus area (expandable)
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
                      content: _summaryText,
                      stats: [
                        SummaryStatItem(
                          label: 'Tasks',
                          value: _taskStats['total'] ?? 0,
                        ),
                        SummaryStatItem(
                          label: 'Unread',
                          value: _taskStats['unread'] ?? 0,
                          valueColor: AuraColors.tether,
                        ),
                      ],
                      onExpand: () => context.push(AppRoutes.summary),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Floating Bottom Navigation
          AuraBottomNav(
            items: const [
              AuraNavItem(icon: LucideIcons.home, label: 'Home'),
              AuraNavItem(icon: LucideIcons.layoutGrid, label: 'Tools'),
            ],
            selectedIndex: _selectedNavIndex,
            onTabChanged: (index) {
              setState(() => _selectedNavIndex = index);
              if (index == 1) {
                context.push(AppRoutes.tools);
              }
            },
          ),
        ],
      ),
    );
  }

  void _handleNucleusActivate() {
    // Only start if not already active to prevent double connection
    if (!_isNucleusActive) {
       ref.read(voiceServiceProvider).startSession();
    }
  }

  void _handleNucleusTap() {
    setState(() {
      _isNucleusActive = false;
      _voiceState = NucleusVoiceState.silence;
    });
    ref.read(voiceServiceProvider).stopSession();
  }



  void _showSettingsMenu() {
    final aura = context.aura;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: aura.bgSecondary,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(LucideIcons.user),
              title: const Text('Profile'),
              onTap: () {
                Navigator.pop(ctx);
                _showComingSoon('Profile');
              },
            ),
            ListTile(
              leading: const Icon(LucideIcons.bell),
              title: const Text('Notifications'),
              onTap: () {
                Navigator.pop(ctx);
                _showComingSoon('Notifications');
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(LucideIcons.logOut, color: AuraColors.heartbeat),
              title: const Text(
                'Sign Out',
                style: TextStyle(color: AuraColors.heartbeat),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _showLogoutDialog();
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature feature coming soon!'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: context.aura.bgSecondary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showLogoutDialog() {
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
            },
          ),
        ],
      ),
    );
  }
}
