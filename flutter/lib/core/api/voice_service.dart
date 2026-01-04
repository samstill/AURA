import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record/record.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../auth/data/auth_repository.dart';
import 'config/env_config.dart';

// Riverpod provider
final voiceServiceProvider = Provider<VoiceService>((ref) {
  return VoiceService(ref);
});

enum VoiceState { silence, listening, processing, speaking }
enum VoiceConnectionState { disconnected, connecting, connected, error }

class VoiceService {
  final Ref _ref;
  final _audioRecorder = AudioRecorder();
  WebSocketChannel? _channel;
  
  // Stream controller for voice state updates
  final _stateController = StreamController<VoiceState>.broadcast();
  Stream<VoiceState> get stateStream => _stateController.stream;

  // Stream controller for connection state
  final _connectionStateController = StreamController<VoiceConnectionState>.broadcast();
  Stream<VoiceConnectionState> get connectionStream => _connectionStateController.stream;

  VoiceService(this._ref);

  Future<void> startSession() async {
    // 1. Get Authentication Token
    final token = await (await _ref.read(authRepositoryProvider.future)).getAccessToken();
    if (token == null) return;

    // 2. Connect WebSocket
    try {
      _connectionStateController.add(VoiceConnectionState.connecting);
      final wsUrl = '${EnvConfig.apiBaseUrl.replaceFirst("http", "ws")}/api/v1/voice/stream?token=$token';
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      await _channel?.ready; // Wait for connection to be ready
      _connectionStateController.add(VoiceConnectionState.connected);
      _stateController.add(VoiceState.listening);
    } catch (e) {
      _connectionStateController.add(VoiceConnectionState.error);
      return;
    }

    // 3. Start Recording
      if (await _audioRecorder.hasPermission()) {
        final stream = await _audioRecorder.startStream(
          const RecordConfig(sampleRate: 16000, numChannels: 1),
        );

      // 4. Stream Audio to WebSocket
      stream.listen((data) {
        _channel?.sink.add(data);
      });
    }

    // 5. Listen for Responses
    _channel?.stream.listen(
      (message) {
        if (message is String) {
          final data = jsonDecode(message);
          if (data['status'] == 'turn_complete') {
             _stateController.add(VoiceState.silence);
          }
        } else if (message is Uint8List) {
          // TODO: Play Audio Chunk
          _stateController.add(VoiceState.speaking);
        }
      },
      onDone: () {
        _stateController.add(VoiceState.silence);
        _connectionStateController.add(VoiceConnectionState.disconnected);
      },
      onError: (e) {
        _stateController.add(VoiceState.silence);
        _connectionStateController.add(VoiceConnectionState.error);
      },
    );
  }

  Future<void> stopSession() async {
    await _audioRecorder.stop();
    await _channel?.sink.close();
    _channel = null;
    _channel = null;
    _stateController.add(VoiceState.silence);
    _connectionStateController.add(VoiceConnectionState.disconnected);
  }
}
