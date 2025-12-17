/// Project Aura - Login Screen
/// ============================
/// Native in-app authentication using Authentik Flows API.
/// Implements the "Tactical Implementation of Desire" design philosophy.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../config/app_config.dart';
import '../../../design_system/design_system.dart';
import '../../data/data.dart';
import '../../domain/domain.dart';
import '../controllers/controllers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _totpController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;
  FlowChallenge? _currentChallenge;

  bool _flowStarted = false;

  @override
  void initState() {
    super.initState();
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
        _errorMessage = result.error?.displayError ?? 'Failed to start login';
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
            result.error?.displayError ?? 'Failed to restart login';
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
    return AuraScaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo with halo glow effect
                _buildLogo().withScaleEntrance(),
                const SizedBox(height: 32),

                // Title
                Text(
                  'Project Aura',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ).withIce(),
                const SizedBox(height: 8),

                Text(
                  'Sign in to continue',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: context.aura.textSecondary,
                      ),
                ).withStaggeredEntrance(index: 1),
                const SizedBox(height: 48),

                // Form content
                _buildStageContent().withStaggeredEntrance(index: 2),
                const SizedBox(height: 32),

                // Server info
                Text(
                  'Authentik: ${AppConfig.host}:${AppConfig.authentikPort}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.aura.textSecondary.withOpacity(0.5),
                        fontFamily: 'monospace',
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AuraColors.heartbeat, AuraColors.tether],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AuraColors.heartbeat.withOpacity(0.4),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: AuraColors.halo.withOpacity(0.2),
            blurRadius: 60,
            spreadRadius: 10,
          ),
        ],
      ),
      child: const Icon(
        LucideIcons.sparkles,
        size: 48,
        color: Colors.white,
      ),
    );
  }

  Widget _buildStageContent() {
    if (_isLoading && _currentChallenge == null) {
      return AuraGlass(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            SizedBox(
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
              SizedBox(
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
    return AuraGlass(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_errorMessage != null) ...[
            _buildErrorMessage(),
            const SizedBox(height: 16),
          ],
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofocus: true,
            style: TextStyle(color: context.aura.textPrimary),
            decoration: InputDecoration(
              labelText: 'Email or Username',
              hintText: 'Enter your email or username',
              prefixIcon: AuraIcon.glass(LucideIcons.user, size: 20),
            ),
            onSubmitted: (_) => _submitIdentification(),
          ),
          const SizedBox(height: 24),
          AuraButton.heartbeat(
            label: 'Continue',
            onPressed: _isLoading ? null : _submitIdentification,
            isLoading: _isLoading,
            fullWidth: true,
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordStage() {
    final challenge = _currentChallenge as PasswordChallenge?;

    return AuraGlass(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (challenge?.pendingUser != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: context.aura.bgSecondary.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.aura.glassBorder),
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
          TextField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            autofocus: true,
            style: TextStyle(color: context.aura.textPrimary),
            decoration: InputDecoration(
              labelText: 'Password',
              hintText: 'Enter your password',
              prefixIcon: AuraIcon.glass(LucideIcons.lock, size: 20),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? LucideIcons.eye : LucideIcons.eyeOff,
                  color: context.aura.textSecondary,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            onSubmitted: (_) => _submitPassword(),
          ),
          const SizedBox(height: 24),
          AuraButton.heartbeat(
            label: 'Sign In',
            onPressed: _isLoading ? null : _submitPassword,
            isLoading: _isLoading,
            fullWidth: true,
          ),
        ],
      ),
    );
  }

  Widget _buildMfaStage() {
    return AuraGlass(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          AuraIcon.halo(LucideIcons.shield, size: 64),
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
          Icon(LucideIcons.ban, size: 64, color: AuraColors.heartbeat),
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
          Icon(LucideIcons.alertCircle, size: 64, color: AuraColors.heartbeat),
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
          AuraIcon.glass(LucideIcons.helpCircle, size: 64),
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
              color: AuraColors.heartbeat.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(LucideIcons.alertTriangle, color: AuraColors.heartbeat),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _errorMessage ?? 'Connection failed',
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
        color: AuraColors.heartbeat.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AuraColors.heartbeat.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.alertCircle, color: AuraColors.heartbeat, size: 20),
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
