// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dio_client.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provides the persistent CookieJar instance (or in-memory on Web)

@ProviderFor(cookieJar)
final cookieJarProvider = CookieJarProvider._();

/// Provides the persistent CookieJar instance (or in-memory on Web)

final class CookieJarProvider extends $FunctionalProvider<AsyncValue<CookieJar>,
        CookieJar, FutureOr<CookieJar>>
    with $FutureModifier<CookieJar>, $FutureProvider<CookieJar> {
  /// Provides the persistent CookieJar instance (or in-memory on Web)
  CookieJarProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'cookieJarProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$cookieJarHash();

  @$internal
  @override
  $FutureProviderElement<CookieJar> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<CookieJar> create(Ref ref) {
    return cookieJar(ref);
  }
}

String _$cookieJarHash() => r'10e1915dc23ef1c224e6624bc9b31bd5da40f159';

/// Provides the configured Dio instance for API calls

@ProviderFor(apiClient)
final apiClientProvider = ApiClientProvider._();

/// Provides the configured Dio instance for API calls

final class ApiClientProvider
    extends $FunctionalProvider<AsyncValue<Dio>, Dio, FutureOr<Dio>>
    with $FutureModifier<Dio>, $FutureProvider<Dio> {
  /// Provides the configured Dio instance for API calls
  ApiClientProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'apiClientProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$apiClientHash();

  @$internal
  @override
  $FutureProviderElement<Dio> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<Dio> create(Ref ref) {
    return apiClient(ref);
  }
}

String _$apiClientHash() => r'cab954fe8e4eade4b6ef6dcae852b20cac9a88ae';

/// Provides the configured Dio instance for Authentik API calls

@ProviderFor(authentikClient)
final authentikClientProvider = AuthentikClientProvider._();

/// Provides the configured Dio instance for Authentik API calls

final class AuthentikClientProvider
    extends $FunctionalProvider<AsyncValue<Dio>, Dio, FutureOr<Dio>>
    with $FutureModifier<Dio>, $FutureProvider<Dio> {
  /// Provides the configured Dio instance for Authentik API calls
  AuthentikClientProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'authentikClientProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$authentikClientHash();

  @$internal
  @override
  $FutureProviderElement<Dio> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<Dio> create(Ref ref) {
    return authentikClient(ref);
  }
}

String _$authentikClientHash() => r'4dbd25ad0d7a8190dc52fc168cf0e165cf6460ea';
