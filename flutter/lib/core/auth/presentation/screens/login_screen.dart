/// Project Aura - Login Screen (Glassmorphic)
/// ===========================================
/// Native in-app authentication using Authentik Flows API.
/// Implements the "Tactical Implementation of Desire" design philosophy.
/// 
/// Features:
/// - Glassmorphic card with blur effects
/// - Animated floating orbs for depth
/// - Theme-aware SVG logo (dark/light)
/// - Premium gradient backgrounds
/// - Bottom accent gradient line
library;

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../design_system/design_system.dart';
import '../../data/data.dart';
import '../../domain/domain.dart';
import '../controllers/controllers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with TickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _totpController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;
  FlowChallenge? _currentChallenge;

  bool _flowStarted = false;

  // Animation controllers for floating orbs
  late AnimationController _orbController1;
  late AnimationController _orbController2;
  late AnimationController _orbController3;

  @override
  void initState() {
    super.initState();

    // Initialize orb animations with different durations for organic movement
    _orbController1 = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);

    _orbController2 = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat(reverse: true);

    _orbController3 = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final isAuthenticated = ref.read(isAuthenticatedProvider);
      if (isAuthenticated) {
        debugPrint('⏭️ Already authenticated, skipping flow start');
        return;
      }

      if (!_flowStarted) {
        _flowStarted = true;
        _startAuthFlow();
      }
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _totpController.dispose();
    _orbController1.dispose();
    _orbController2.dispose();
    _orbController3.dispose();
    super.dispose();
  }

  Future<void> _startAuthFlow({int retryCount = 0}) async {
    if (_isLoading && retryCount == 0) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result =
        await ref.read(authControllerProvider.notifier).startAuthFlow();

    if (!mounted) return;

    if (result.challenge?.component == FlowComponentType.flowError &&
        retryCount < 2) {
      debugPrint('⚠️ Got flow error on attempt ${retryCount + 1}, retrying...');
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        await ref.read(authControllerProvider.notifier).restartAuthFlow();
        await _startAuthFlow(retryCount: retryCount + 1);
      }
      return;
    }

    setState(() {
      _isLoading = false;
      if (result.success) {
        _currentChallenge = result.challenge;
      } else {
        _errorMessage = result.error?.displayError ?? "Let's try connecting again...";
      }
    });
  }

  Future<void> _restartAuthFlow() async {
    _emailController.clear();
    _passwordController.clear();
    _totpController.clear();

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _currentChallenge = null;
    });

    final result =
        await ref.read(authControllerProvider.notifier).restartAuthFlow();

    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (result.success) {
        _currentChallenge = result.challenge;
      } else {
        _errorMessage =
            result.error?.displayError ?? "Let's start fresh...";
      }
    });
  }

  Future<void> _submitIdentification() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _errorMessage = 'Please enter your email or username');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result =
        await ref.read(authControllerProvider.notifier).submitIdentification(email);

    if (!mounted) return;
    _handleFlowResult(result);
  }

  Future<void> _submitPassword() async {
    final password = _passwordController.text;
    if (password.isEmpty) {
      setState(() => _errorMessage = 'Please enter your password');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result =
        await ref.read(authControllerProvider.notifier).submitPassword(password);

    if (!mounted) return;
    _handleFlowResult(result);
  }

  Future<void> _submitTotp() async {
    final code = _totpController.text.trim();
    if (code.isEmpty) {
      setState(() => _errorMessage = 'Please enter your verification code');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result =
        await ref.read(authControllerProvider.notifier).submitTotp(code);

    if (!mounted) return;
    _handleFlowResult(result);
  }

  Future<void> _handleFlowResult(FlowResult result) async {
    setState(() {
      _isLoading = false;

      if (result.error != null &&
          result.error!.nonFieldErrors != '_CONTINUE_FLOW_') {
        _errorMessage = result.error!.displayError;
      }

      if (result.challenge != null) {
        _currentChallenge = result.challenge;

        if (result.challenge!.isSuccess) {
          debugPrint('🎉 Auth success - navigating to home...');
          _isLoading = true;
        }
      }
    });

    if (result.challenge?.isSuccess == true) {
      debugPrint('🎉 Auth success - router will redirect automatically');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final aura = context.aura;

    // Keep controller alive while screen is mounted
    ref.watch(authControllerProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Gradient Background
          _buildGradientBackground(isDark, aura),

          // Floating Orbs
          _buildFloatingOrbs(isDark),

          // Main Content
          SafeArea(
            child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(32.0),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 400),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Logo
                          _buildLogo(isDark).withScaleEntrance(),
                          const SizedBox(height: 40),

                          // Title
                          Text(
                            'Welcome Back',
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: aura.textPrimary,
                                ),
                          ).withIce(),
                          const SizedBox(height: 8),

                          Text(
                            'Enter your credentials to continue',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: aura.textSecondary,
                                ),
                          ).withStaggeredEntrance(index: 1),
                          const SizedBox(height: 40),

                          // Form content
                          _buildStageContent().withStaggeredEntrance(index: 2),
                        ],
                      ),
                    ),
                  ),
                ),
          ),

          // Bottom Accent Line
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildBottomAccent(isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildGradientBackground(bool isDark, AuraColors aura) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 800),
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0, -0.5),
          radius: 1.5,
          colors: isDark
              ? [
                  const Color(0xFF121212),
                  const Color(0xFF080808),
                  aura.bgPrimary,
                ]
              : [
                  const Color(0xFFFFF5F7),
                  const Color(0xFFFFF9F5),
                  aura.bgPrimary,
                ],
          stops: isDark ? const [0.0, 0.4, 1.0] : const [0.0, 0.3, 1.0],
        ),
      ),
    );
  }

  Widget _buildFloatingOrbs(bool isDark) {
    return Stack(
      children: [
        // Purple/Tether orb - top left with curved motion
        AnimatedBuilder(
          animation: _orbController1,
          builder: (context, child) {
            // Use curved animation for smooth organic movement
            final curvedValue = Curves.easeInOut.transform(_orbController1.value);
            final sinValue = sin(curvedValue * pi * 2) * 0.5 + 0.5;
            
            return Positioned(
              top: MediaQuery.of(context).size.height * 0.1 +
                  (curvedValue * 50) + (sinValue * 20),
              left: MediaQuery.of(context).size.width * 0.05 +
                  (sinValue * 40),
              child: Transform.scale(
                scale: 1.0 + (curvedValue * 0.15),
                child: _FloatingOrb(
                  color: AuraColors.tether,
                  size: 350,
                  opacity: (isDark ? 0.2 : 0.35) + (sinValue * 0.05),
                  blurRadius: 100,
                ),
              ),
            );
          },
        ),

        // Pink/Heartbeat orb - bottom right with pulsing motion
        AnimatedBuilder(
          animation: _orbController2,
          builder: (context, child) {
            final curvedValue = Curves.easeInOut.transform(_orbController2.value);
            final cosValue = cos(curvedValue * pi * 2) * 0.5 + 0.5;
            
            return Positioned(
              bottom: MediaQuery.of(context).size.height * 0.1 +
                  (curvedValue * 60) + (cosValue * 25),
              right: MediaQuery.of(context).size.width * 0.05 +
                  (cosValue * 50),
              child: Transform.scale(
                scale: 1.0 + (cosValue * 0.2),
                child: _FloatingOrb(
                  color: AuraColors.heartbeat,
                  size: 300,
                  opacity: (isDark ? 0.18 : 0.32) + (curvedValue * 0.05),
                  blurRadius: 90,
                ),
              ),
            );
          },
        ),

        // Cyan/Halo orb - center right with floating motion
        AnimatedBuilder(
          animation: _orbController3,
          builder: (context, child) {
            final curvedValue = Curves.easeInOut.transform(_orbController3.value);
            final sinValue = sin(curvedValue * pi * 2) * 0.5 + 0.5;
            
            return Positioned(
              top: MediaQuery.of(context).size.height * 0.35 +
                  (sinValue * 80),
              right: MediaQuery.of(context).size.width * 0.15 +
                  (curvedValue * 60),
              child: Transform.scale(
                scale: 1.0 + (sinValue * 0.1),
                child: _FloatingOrb(
                  color: AuraColors.halo,
                  size: 250,
                  opacity: (isDark ? 0.12 : 0.28) + (curvedValue * 0.03),
                  blurRadius: 80,
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildLogo(bool isDark) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: AuraColors.tether.withValues(alpha: 0.3),
            blurRadius: 30,
            spreadRadius: 5,
          ),
        ],
      ),
      child: SvgPicture.asset(
        isDark ? 'assets/icons/logo_light.svg' : 'assets/icons/icon_dark.svg',
        width: 80,
        height: 80,
      ),
    ).withJelly(onPressed: null);
  }

  Widget _buildBottomAccent(bool isDark) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 800),
      opacity: isDark ? 0.3 : 0.25,
      child: Container(
        height: 2,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.transparent,
              AuraColors.tether,
              AuraColors.heartbeat,
              AuraColors.halo,
              Colors.transparent,
            ],
            stops: [0.0, 0.25, 0.5, 0.75, 1.0],
          ),
        ),
      ),
    );
  }

  Widget _buildStageContent() {
    if (_isLoading && _currentChallenge == null) {
      return AuraGlass(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            const SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation(AuraColors.halo),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Connecting to authentication server...',
              style: TextStyle(color: context.aura.textSecondary),
            ),
          ],
        ),
      );
    }

    if (_currentChallenge == null) {
      return _buildErrorCard();
    }

    switch (_currentChallenge!.component) {
      case FlowComponentType.identification:
        return _buildIdentificationStage();
      case FlowComponentType.password:
        return _buildPasswordStage();
      case FlowComponentType.authenticatorValidate:
        return _buildMfaStage();
      case FlowComponentType.accessDenied:
        return _buildAccessDeniedStage();
      case FlowComponentType.flowError:
        return _buildFlowErrorStage();
      case FlowComponentType.redirect:
        return AuraGlass(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              const SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation(AuraColors.halo),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Login successful! Redirecting...',
                style: TextStyle(color: context.aura.textSecondary),
              ),
            ],
          ),
        );
      default:
        return _buildUnknownStage();
    }
  }

  Widget _buildIdentificationStage() {
    final aura = context.aura;

    return AuraGlass(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_errorMessage != null) ...[
            _buildErrorMessage(),
            const SizedBox(height: 16),
          ],
          Text(
            'Email',
            style: TextStyle(
              color: aura.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          _buildInputField(
            controller: _emailController,
            hintText: 'your@email.com',
            keyboardType: TextInputType.emailAddress,
            prefixIcon: LucideIcons.user,
            onSubmitted: (_) => _submitIdentification(),
          ),
          const SizedBox(height: 24),
          AuraButton.heartbeat(
            label: 'Continue',
            onPressed: _isLoading ? null : _submitIdentification,
            isLoading: _isLoading,
            fullWidth: true,
          ),
          const SizedBox(height: 24),
          Center(
            child: Text.rich(
              TextSpan(
                text: "Don't have an account? ",
                style: TextStyle(
                  color: aura.textSecondary,
                  fontSize: 14,
                ),
                children: [
                  WidgetSpan(
                    child: GestureDetector(
                      onTap: () {
                        // Handle sign up navigation
                      },
                      child: const Text(
                        'Sign up',
                        style: TextStyle(
                          color: AuraColors.tether,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordStage() {
    final challenge = _currentChallenge as PasswordChallenge?;
    final aura = context.aura;

    return AuraGlass(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (challenge?.pendingUser != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: aura.bgSecondary.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: aura.glassBorder),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AuraColors.tether,
                    child: Text(
                      challenge!.pendingUser![0].toUpperCase(),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      challenge.pendingUser!,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  AuraIconButton(
                    icon: LucideIcons.x,
                    onPressed: _isLoading ? null : _restartAuthFlow,
                    tooltip: 'Sign in with different account',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
          if (_errorMessage != null) ...[
            _buildErrorMessage(),
            const SizedBox(height: 16),
          ],
          Text(
            'Password',
            style: TextStyle(
              color: aura.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          _buildInputField(
            controller: _passwordController,
            hintText: '••••••••',
            obscureText: _obscurePassword,
            prefixIcon: LucideIcons.lock,
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? LucideIcons.eye : LucideIcons.eyeOff,
                color: aura.textSecondary,
                size: 20,
              ),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
            onSubmitted: (_) => _submitPassword(),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: () {
                // Handle forgot password
              },
              child: const Text(
                'Forgot password?',
                style: TextStyle(
                  color: AuraColors.tether,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          AuraButton.heartbeat(
            label: 'Sign In',
            onPressed: _isLoading ? null : _submitPassword,
            isLoading: _isLoading,
            fullWidth: true,
          ),
          const SizedBox(height: 24),
          Center(
            child: Text.rich(
              TextSpan(
                text: "Don't have an account? ",
                style: TextStyle(
                  color: aura.textSecondary,
                  fontSize: 14,
                ),
                children: [
                  WidgetSpan(
                    child: GestureDetector(
                      onTap: () {
                        // Handle sign up navigation
                      },
                      child: const Text(
                        'Sign up',
                        style: TextStyle(
                          color: AuraColors.tether,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String hintText,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    IconData? prefixIcon,
    Widget? suffixIcon,
    void Function(String)? onSubmitted,
  }) {
    final aura = context.aura;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      autofocus: true,
      style: TextStyle(color: aura.textPrimary, fontSize: 15),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(color: aura.textSecondary.withValues(alpha: 0.5)),
        prefixIcon: prefixIcon != null
            ? Icon(prefixIcon, color: aura.textSecondary, size: 20)
            : null,
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : const Color(0xFFF2E8E6).withValues(alpha: 0.4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : const Color(0xFFA67C82).withValues(alpha: 0.25),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : const Color(0xFFA67C82).withValues(alpha: 0.25),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: AuraColors.tether,
            width: 1.5,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      onSubmitted: onSubmitted,
    );
  }

  Widget _buildMfaStage() {
    return AuraGlass(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const AuraIcon.halo(LucideIcons.shield, size: 64),
          const SizedBox(height: 16),
          Text(
            'Two-Factor Authentication',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Enter the code from your authenticator app',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: context.aura.textSecondary,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          if (_errorMessage != null) ...[
            _buildErrorMessage(),
            const SizedBox(height: 16),
          ],
          TextField(
            controller: _totpController,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: 6,
            autofocus: true,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  letterSpacing: 8,
                  fontWeight: FontWeight.bold,
                  color: context.aura.textPrimary,
                ),
            decoration: const InputDecoration(
              hintText: '000000',
              counterText: '',
            ),
            onSubmitted: (_) => _submitTotp(),
          ),
          const SizedBox(height: 24),
          AuraButton.heartbeat(
            label: 'Verify',
            onPressed: _isLoading ? null : _submitTotp,
            isLoading: _isLoading,
            fullWidth: true,
          ),
        ],
      ),
    );
  }

  Widget _buildAccessDeniedStage() {
    final challenge = _currentChallenge as AccessDeniedChallenge?;

    return AuraGlass(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Icon(LucideIcons.ban, size: 64, color: AuraColors.heartbeat),
          const SizedBox(height: 16),
          Text(
            'Access Denied',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AuraColors.heartbeat,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            challenge?.errorMessage ?? 'Authentication failed',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: context.aura.textSecondary,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          AuraButton.ghost(
            label: 'Try Again',
            onPressed: _isLoading ? null : _restartAuthFlow,
          ),
        ],
      ),
    );
  }

  Widget _buildFlowErrorStage() {
    final challenge = _currentChallenge as FlowErrorChallenge?;

    return AuraGlass(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Icon(LucideIcons.alertCircle, size: 64, color: AuraColors.heartbeat),
          const SizedBox(height: 16),
          Text(
            'Authentication Error',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AuraColors.heartbeat,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            challenge?.errorMessage ??
                'An error occurred during authentication. Please try again.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: context.aura.textSecondary,
                ),
            textAlign: TextAlign.center,
          ),
          if (challenge?.requestId != null) ...[
            const SizedBox(height: 8),
            Text(
              'Request ID: ${challenge!.requestId}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                    color: context.aura.textSecondary,
                  ),
            ),
          ],
          const SizedBox(height: 24),
          AuraButton.heartbeat(
            label: 'Start Over',
            icon: LucideIcons.refreshCw,
            onPressed: _isLoading ? null : _restartAuthFlow,
          ),
        ],
      ),
    );
  }

  Widget _buildUnknownStage() {
    debugPrint(
        '⚠️ Unknown stage component: ${_currentChallenge?.component.value}');
    debugPrint('⚠️ Raw data: ${_currentChallenge?.rawData}');

    return AuraGlass(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const AuraIcon.glass(LucideIcons.helpCircle, size: 64),
          const SizedBox(height: 16),
          Text(
            'Unknown Stage',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Component: ${_currentChallenge?.component.value ?? "null"}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                  color: context.aura.textSecondary,
                ),
          ),
          const SizedBox(height: 16),
          AuraButton.ghost(
            label: 'Restart',
            onPressed: _isLoading ? null : _restartAuthFlow,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard() {
    return AuraGlass(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AuraColors.heartbeat.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(LucideIcons.alertTriangle, color: AuraColors.heartbeat),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _errorMessage ?? "We're having trouble connecting. Let's try again.",
                    style: TextStyle(color: context.aura.textPrimary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          AuraButton.ghost(
            label: 'Retry',
            icon: LucideIcons.refreshCw,
            onPressed: _isLoading ? null : _restartAuthFlow,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AuraColors.heartbeat.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AuraColors.heartbeat.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.alertCircle, color: AuraColors.heartbeat, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage!,
              style: TextStyle(
                color: context.aura.textPrimary,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Floating orb widget for background depth
class _FloatingOrb extends StatelessWidget {
  final Color color;
  final double size;
  final double opacity;
  final double blurRadius;

  const _FloatingOrb({
    required this.color,
    required this.size,
    required this.opacity,
    required this.blurRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withOpacity(opacity),
            color.withValues(alpha: 0),
          ],
          stops: const [0.0, 0.7],
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(opacity * 0.5),
            blurRadius: blurRadius,
            spreadRadius: size * 0.1,
          ),
        ],
      ),
    );
  }
}
