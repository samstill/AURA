// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dio_client.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$cookieJarHash() => r'55152c7260f32fc5cdcf50b27ab2e532ac09e556';

/// Provides the shared CookieJar instance
///
/// Copied from [cookieJar].
@ProviderFor(cookieJar)
final cookieJarProvider = Provider<CookieJar>.internal(
  cookieJar,
  name: r'cookieJarProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$cookieJarHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef CookieJarRef = ProviderRef<CookieJar>;
String _$apiClientHash() => r'127a837a41de0629787f700a2d3cd63c8c29d1e0';

/// Provides the configured Dio instance for API calls
///
/// Copied from [apiClient].
@ProviderFor(apiClient)
final apiClientProvider = Provider<Dio>.internal(
  apiClient,
  name: r'apiClientProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$apiClientHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ApiClientRef = ProviderRef<Dio>;
String _$authentikClientHash() => r'9a4f265f8c94e2e9192bb27f75eb5d66c1f8732f';

/// Provides the configured Dio instance for Authentik API calls
///
/// Copied from [authentikClient].
@ProviderFor(authentikClient)
final authentikClientProvider = Provider<Dio>.internal(
  authentikClient,
  name: r'authentikClientProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$authentikClientHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef AuthentikClientRef = ProviderRef<Dio>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
