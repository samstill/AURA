// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dio_client.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$cookieJarHash() => r'b405ed2afa3ddf9d4ab556f5a2f50474deeb32e3';

/// Provides the persistent CookieJar instance
///
/// Copied from [cookieJar].
@ProviderFor(cookieJar)
final cookieJarProvider = FutureProvider<PersistCookieJar>.internal(
  cookieJar,
  name: r'cookieJarProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$cookieJarHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef CookieJarRef = FutureProviderRef<PersistCookieJar>;
String _$apiClientHash() => r'f8b5e36e03333c7838566ee618173bbcfa434c88';

/// Provides the configured Dio instance for API calls
///
/// Copied from [apiClient].
@ProviderFor(apiClient)
final apiClientProvider = FutureProvider<Dio>.internal(
  apiClient,
  name: r'apiClientProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$apiClientHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ApiClientRef = FutureProviderRef<Dio>;
String _$authentikClientHash() => r'5740c5a17890398d3266469e1b5215a5be901098';

/// Provides the configured Dio instance for Authentik API calls
///
/// Copied from [authentikClient].
@ProviderFor(authentikClient)
final authentikClientProvider = FutureProvider<Dio>.internal(
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
typedef AuthentikClientRef = FutureProviderRef<Dio>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
