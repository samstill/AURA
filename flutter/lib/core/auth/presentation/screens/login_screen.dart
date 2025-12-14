/// Project Aura - Login Screen
/// ============================
/// Native in-app authentication using Authentik Flows API.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/app_config.dart';
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


  @override
  void initState() {
    super.initState();
    // Defer auth flow start until after widget tree is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startAuthFlow();
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _totpController.dispose();
    super.dispose();
  }

  Future<void> _startAuthFlow() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await ref.read(authControllerProvider.notifier).startAuthFlow();

    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (result.success) {
        _currentChallenge = result.challenge;
      } else {
        _errorMessage = result.error?.displayError ?? 'Failed to start login';
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

    final result = await ref.read(authControllerProvider.notifier).submitIdentification(email);

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

    final result = await ref.read(authControllerProvider.notifier).submitPassword(password);

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

    final result = await ref.read(authControllerProvider.notifier).submitTotp(code);

    if (!mounted) return;
    _handleFlowResult(result);
  }

  void _handleFlowResult(FlowResult result) {
    setState(() {
      _isLoading = false;
      
      if (result.error != null && result.error!.nonFieldErrors != '_CONTINUE_FLOW_') {
        _errorMessage = result.error!.displayError;
      }
      
      if (result.challenge != null) {
        _currentChallenge = result.challenge;
        
        if (result.challenge!.isSuccess) {
          context.go('/');
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLogo(colorScheme),
                const SizedBox(height: 32),
                Text(
                  'Project Aura',
                  style: theme.textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Sign in to continue',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 48),
                _buildStageContent(theme, colorScheme),
                const SizedBox(height: 32),
                Text(
                  'Authentik: ${AppConfig.host}:${AppConfig.authentikPort}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.outline,
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

  Widget _buildLogo(ColorScheme colorScheme) {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colorScheme.primary, colorScheme.tertiary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Icon(
        Icons.auto_awesome,
        size: 48,
        color: colorScheme.onPrimary,
      ),
    );
  }

  Widget _buildStageContent(ThemeData theme, ColorScheme colorScheme) {
    if (_isLoading && _currentChallenge == null) {
      return const Column(
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Connecting to authentication server...'),
        ],
      );
    }

    if (_currentChallenge == null) {
      return _buildErrorCard(colorScheme);
    }

    switch (_currentChallenge!.component) {
      case FlowComponentType.identification:
        return _buildIdentificationStage(colorScheme);
      case FlowComponentType.password:
        return _buildPasswordStage(theme, colorScheme);
      case FlowComponentType.authenticatorValidate:
        return _buildMfaStage(theme, colorScheme);
      case FlowComponentType.accessDenied:
        return _buildAccessDeniedStage(theme, colorScheme);
      default:
        return _buildUnknownStage(theme);
    }
  }

  Widget _buildIdentificationStage(ColorScheme colorScheme) {
    return Column(
      children: [
        if (_errorMessage != null) ...[
          _buildErrorMessage(colorScheme),
          const SizedBox(height: 16),
        ],
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Email or Username',
            hintText: 'Enter your email or username',
            prefixIcon: const Icon(Icons.person_outline),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onSubmitted: (_) => _submitIdentification(),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _isLoading ? null : _submitIdentification,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: _isLoading
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Continue'),
        ),
      ],
    );
  }

  Widget _buildPasswordStage(ThemeData theme, ColorScheme colorScheme) {
    final challenge = _currentChallenge as PasswordChallenge?;
    
    return Column(
      children: [
        if (challenge?.pendingUser != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: colorScheme.primary,
                  child: Text(
                    challenge!.pendingUser![0].toUpperCase(),
                    style: TextStyle(color: colorScheme.onPrimary),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(challenge.pendingUser!, style: theme.textTheme.titleMedium),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: _startAuthFlow,
                  tooltip: 'Sign in with different account',
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
        if (_errorMessage != null) ...[
          _buildErrorMessage(colorScheme),
          const SizedBox(height: 16),
        ],
        TextField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Password',
            hintText: 'Enter your password',
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onSubmitted: (_) => _submitPassword(),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _isLoading ? null : _submitPassword,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: _isLoading
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Sign In'),
        ),
      ],
    );
  }

  Widget _buildMfaStage(ThemeData theme, ColorScheme colorScheme) {
    return Column(
      children: [
        Icon(Icons.security, size: 64, color: colorScheme.primary),
        const SizedBox(height: 16),
        Text('Two-Factor Authentication', style: theme.textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(
          'Enter the code from your authenticator app',
          style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        if (_errorMessage != null) ...[
          _buildErrorMessage(colorScheme),
          const SizedBox(height: 16),
        ],
        TextField(
          controller: _totpController,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 6,
          autofocus: true,
          style: theme.textTheme.headlineMedium?.copyWith(letterSpacing: 8, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            hintText: '000000',
            counterText: '',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onSubmitted: (_) => _submitTotp(),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _isLoading ? null : _submitTotp,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: _isLoading
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Verify'),
        ),
      ],
    );
  }

  Widget _buildAccessDeniedStage(ThemeData theme, ColorScheme colorScheme) {
    final challenge = _currentChallenge as AccessDeniedChallenge?;
    
    return Column(
      children: [
        Icon(Icons.block, size: 64, color: colorScheme.error),
        const SizedBox(height: 16),
        Text('Access Denied', style: theme.textTheme.titleLarge?.copyWith(color: colorScheme.error)),
        const SizedBox(height: 8),
        Text(
          challenge?.errorMessage ?? 'Authentication failed',
          style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        OutlinedButton(onPressed: _startAuthFlow, child: const Text('Try Again')),
      ],
    );
  }

  Widget _buildUnknownStage(ThemeData theme) {
    return Column(
      children: [
        const Icon(Icons.help_outline, size: 64),
        const SizedBox(height: 16),
        Text('Unknown Stage', style: theme.textTheme.titleLarge),
        const SizedBox(height: 16),
        OutlinedButton(onPressed: _startAuthFlow, child: const Text('Restart')),
      ],
    );
  }

  Widget _buildErrorCard(ColorScheme colorScheme) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.errorContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.error_outline, color: colorScheme.error),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _errorMessage ?? 'Connection failed',
                  style: TextStyle(color: colorScheme.onErrorContainer),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: _startAuthFlow,
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
        ),
      ],
    );
  }

  Widget _buildErrorMessage(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: colorScheme.error, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage!,
              style: TextStyle(color: colorScheme.onErrorContainer, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
