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
///
/// This client includes:
/// - AuthInterceptor for Bearer token injection
/// - Automatic token refresh on 401
/// - Structured error logging

@ProviderFor(apiClient)
final apiClientProvider = ApiClientProvider._();

/// Provides the configured Dio instance for API calls
///
/// This client includes:
/// - AuthInterceptor for Bearer token injection
/// - Automatic token refresh on 401
/// - Structured error logging

final class ApiClientProvider
    extends $FunctionalProvider<AsyncValue<Dio>, Dio, FutureOr<Dio>>
    with $FutureModifier<Dio>, $FutureProvider<Dio> {
  /// Provides the configured Dio instance for API calls
  ///
  /// This client includes:
  /// - AuthInterceptor for Bearer token injection
  /// - Automatic token refresh on 401
  /// - Structured error logging
  ApiClientProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'apiClientProvider',
          isAutoDispose: false,
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

String _$apiClientHash() => r'a01e9c0ff2da110239dc02f35cbb51adff8e9bad';

/// Provides the configured Dio instance for Authentik API calls
///
/// This client is specifically for Authentik Flows API.
/// Does NOT use AuthInterceptor (would cause circular dependency).
/// Includes certificate pinning for auth.encresa.com in production.

@ProviderFor(authentikClient)
final authentikClientProvider = AuthentikClientProvider._();

/// Provides the configured Dio instance for Authentik API calls
///
/// This client is specifically for Authentik Flows API.
/// Does NOT use AuthInterceptor (would cause circular dependency).
/// Includes certificate pinning for auth.encresa.com in production.

final class AuthentikClientProvider
    extends $FunctionalProvider<AsyncValue<Dio>, Dio, FutureOr<Dio>>
    with $FutureModifier<Dio>, $FutureProvider<Dio> {
  /// Provides the configured Dio instance for Authentik API calls
  ///
  /// This client is specifically for Authentik Flows API.
  /// Does NOT use AuthInterceptor (would cause circular dependency).
  /// Includes certificate pinning for auth.encresa.com in production.
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

String _$authentikClientHash() => r'02f96245f9b06370c0ac349e056132467c19d80e';
