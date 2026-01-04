// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Auth state controller using AsyncNotifier

@ProviderFor(AuthController)
final authControllerProvider = AuthControllerProvider._();

/// Auth state controller using AsyncNotifier
final class AuthControllerProvider
    extends $AsyncNotifierProvider<AuthController, AuthState> {
  /// Auth state controller using AsyncNotifier
  AuthControllerProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'authControllerProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$authControllerHash();

  @$internal
  @override
  AuthController create() => AuthController();
}

String _$authControllerHash() => r'1ee201531654b1bbd5b6448a942718934eac6688';

/// Auth state controller using AsyncNotifier

abstract class _$AuthController extends $AsyncNotifier<AuthState> {
  FutureOr<AuthState> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<AuthState>, AuthState>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<AsyncValue<AuthState>, AuthState>,
        AsyncValue<AuthState>,
        Object?,
        Object?>;
    element.handleCreate(ref, build);
  }
}

/// Convenience providers

@ProviderFor(isAuthenticated)
final isAuthenticatedProvider = IsAuthenticatedProvider._();

/// Convenience providers

final class IsAuthenticatedProvider
    extends $FunctionalProvider<bool, bool, bool> with $Provider<bool> {
  /// Convenience providers
  IsAuthenticatedProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'isAuthenticatedProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$isAuthenticatedHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return isAuthenticated(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$isAuthenticatedHash() => r'932fdc2cbcb1d93e52dc8799f90317a50029531c';

@ProviderFor(currentChallenge)
final currentChallengeProvider = CurrentChallengeProvider._();

final class CurrentChallengeProvider
    extends $FunctionalProvider<FlowChallenge?, FlowChallenge?, FlowChallenge?>
    with $Provider<FlowChallenge?> {
  CurrentChallengeProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'currentChallengeProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$currentChallengeHash();

  @$internal
  @override
  $ProviderElement<FlowChallenge?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  FlowChallenge? create(Ref ref) {
    return currentChallenge(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FlowChallenge? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FlowChallenge?>(value),
    );
  }
}

String _$currentChallengeHash() => r'2533580a4a7395f5662a90c975829420677a4819';
