import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../../core/router/app_router.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final aura = context.aura;

    // Use AuraOrbBackground consistent with other screens
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
            'Profile',
            style: TextStyle(
              color: aura.textPrimary,
              fontFamily: 'Outfit',
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Avatar with glow effect
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
                  radius: 60,
                  backgroundColor: AuraColors.heartbeat.withValues(alpha: 0.1),
                  child: const CircleAvatar(
                    radius: 58,
                    backgroundImage: NetworkImage('https://i.pravatar.cc/150?img=11'),
                  ),
                ),
              ).withScaleEntrance(),
              const SizedBox(height: 24),
              
              Text(
                'User Name',
                style: TextStyle(
                  color: aura.textPrimary,
                  fontFamily: 'Outfit',
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ).withIce(delay: AuraMotion.quick),
              const SizedBox(height: 8),
              Text(
                'user@encresa.com',
                style: TextStyle(
                  color: aura.textPrimary.withValues(alpha: 0.5),
                  fontFamily: 'Manrope',
                  fontSize: 16,
                ),
              ).withIce(delay: AuraMotion.standard),
              
              const SizedBox(height: 48),
              
              // Glassmorphic Sign Out Button with Tension press
              AuraGlass(
                width: 200,
                padding: const EdgeInsets.all(4), // minimal padding container
                borderRadius: BorderRadius.circular(16),
                child: AuraButton(
                  label: 'Sign Out',
                  icon: LucideIcons.logOut,
                  variant: AuraButtonVariant.heartbeat,
                  onPressed: () {
                    AuthChangeNotifier.instance.setAuthenticated(false);
                  },
                ),
              ).withIce(delay: AuraMotion.deliberate),
            ],
          ),
        ),
      ),
    );
  }
}
