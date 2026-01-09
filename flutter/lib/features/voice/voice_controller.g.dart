// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'voice_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(VoiceController)
final voiceControllerProvider = VoiceControllerProvider._();

final class VoiceControllerProvider
    extends $NotifierProvider<VoiceController, VoiceSession> {
  VoiceControllerProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'voiceControllerProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$voiceControllerHash();

  @$internal
  @override
  VoiceController create() => VoiceController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(VoiceSession value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<VoiceSession>(value),
    );
  }
}

String _$voiceControllerHash() => r'f1feeabc44e03d7dcd2b4ee19b1c4adff4319a56';

abstract class _$VoiceController extends $Notifier<VoiceSession> {
  VoiceSession build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<VoiceSession, VoiceSession>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<VoiceSession, VoiceSession>,
        VoiceSession,
        Object?,
        Object?>;
    element.handleCreate(ref, build);
  }
}
