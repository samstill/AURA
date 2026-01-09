// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'home_tab.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provider for secretary brief data with auto-refresh

@ProviderFor(secretaryBrief)
final secretaryBriefProvider = SecretaryBriefProvider._();

/// Provider for secretary brief data with auto-refresh

final class SecretaryBriefProvider extends $FunctionalProvider<
        AsyncValue<SecretaryBrief>, SecretaryBrief, FutureOr<SecretaryBrief>>
    with $FutureModifier<SecretaryBrief>, $FutureProvider<SecretaryBrief> {
  /// Provider for secretary brief data with auto-refresh
  SecretaryBriefProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'secretaryBriefProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$secretaryBriefHash();

  @$internal
  @override
  $FutureProviderElement<SecretaryBrief> $createElement(
          $ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<SecretaryBrief> create(Ref ref) {
    return secretaryBrief(ref);
  }
}

String _$secretaryBriefHash() => r'd669ec0467fba23d98753181f1002b0a940c83e3';

/// Provider for notifications list

@ProviderFor(notifications)
final notificationsProvider = NotificationsProvider._();

/// Provider for notifications list

final class NotificationsProvider extends $FunctionalProvider<
        AsyncValue<List<NotificationItem>>,
        List<NotificationItem>,
        FutureOr<List<NotificationItem>>>
    with
        $FutureModifier<List<NotificationItem>>,
        $FutureProvider<List<NotificationItem>> {
  /// Provider for notifications list
  NotificationsProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'notificationsProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$notificationsHash();

  @$internal
  @override
  $FutureProviderElement<List<NotificationItem>> $createElement(
          $ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<List<NotificationItem>> create(Ref ref) {
    return notifications(ref);
  }
}

String _$notificationsHash() => r'f913979000639a06fc3d7add64acb368262ab621';
