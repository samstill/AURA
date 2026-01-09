/// Voice Controller
/// =================
/// Manages real-time voice conversation with backend secretary.
/// 
/// Flow: Record audio → Stream to WebSocket → Receive TTS → Play audio
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:record/record.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../core/auth/data/auth_repository.dart';
import '../../core/config/app_config.dart';

part 'voice_controller.g.dart';

/// Voice session state
enum VoiceState {
  idle,        // Not active
  connecting,  // Connecting to WebSocket
  listening,   // Recording user's voice
  transcribing,// Converting speech to text
  processing,  // AI is thinking
  speaking,    // Playing TTS response
  error,       // Error occurred
}

/// Voice session data
class VoiceSession {
  final VoiceState state;
  final String? transcription;
  final String? errorMessage;
  final bool isConnected;

  const VoiceSession({
    this.state = VoiceState.idle,
    this.transcription,
    this.errorMessage,
    this.isConnected = false,
  });

  VoiceSession copyWith({
    VoiceState? state,
    String? transcription,
    String? errorMessage,
    bool? isConnected,
  }) {
    return VoiceSession(
      state: state ?? this.state,
      transcription: transcription ?? this.transcription,
      errorMessage: errorMessage,
      isConnected: isConnected ?? this.isConnected,
    );
  }
}

@riverpod
class VoiceController extends _$VoiceController {
  WebSocketChannel? _channel;
  final _recorder = AudioRecorder();
  AudioPlayer? _player;
  StreamSubscription? _recordSubscription;
  StreamSubscription? _wsSubscription;
  
  // Audio buffer for TTS playback
  final _audioBuffer = <Uint8List>[];
  bool _isPlayingAudio = false;

  @override
  VoiceSession build() {
    ref.onDispose(() {
      _cleanup();
    });
    return const VoiceSession();
  }

  /// Start voice session - connect and begin listening
  Future<void> startSession() async {
    if (state.state != VoiceState.idle) return;
    
    state = state.copyWith(state: VoiceState.connecting, errorMessage: null);
    
    try {
      // 1. Get auth token
      final authRepo = await ref.read(authRepositoryProvider.future);
      final token = await authRepo.getAccessToken();
      
      if (token == null) {
        state = state.copyWith(
          state: VoiceState.error,
          errorMessage: 'Not authenticated',
        );
        return;
      }
      
      // 2. Configure audio session
      final audioSession = await AudioSession.instance;
      await audioSession.configure(const AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
        avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.defaultToSpeaker,
        avAudioSessionMode: AVAudioSessionMode.voiceChat,
        androidAudioAttributes: AndroidAudioAttributes(
          contentType: AndroidAudioContentType.speech,
          usage: AndroidAudioUsage.voiceCommunication,
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
      ));
      
      // 3. Connect WebSocket
      final wsUrl = '${AppConfig.apiBaseUrl.replaceFirst("http", "ws")}/voice/stream?token=$token';
      debugPrint('🎤 Connecting to: $wsUrl');
      
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      await _channel!.ready;
      
      // 4. Listen for messages
      _wsSubscription = _channel!.stream.listen(
        _handleWebSocketMessage,
        onError: _handleWebSocketError,
        onDone: _handleWebSocketDone,
      );
      
      state = state.copyWith(state: VoiceState.idle, isConnected: true);
      
      // 5. Start recording
      await _startRecording();
      
    } catch (e) {
      debugPrint('❌ Voice connection error: $e');
      state = state.copyWith(
        state: VoiceState.error,
        errorMessage: 'Connection failed: ${e.toString().split(':').last}',
      );
    }
  }

  /// Stop current session
  Future<void> stopSession() async {
    await _cleanup();
    state = const VoiceSession();
  }

  /// Send end_turn signal to trigger STT
  Future<void> endTurn() async {
    if (state.state != VoiceState.listening) return;
    
    // Stop recording
    await _recorder.stop();
    _recordSubscription?.cancel();
    
    // Send end_turn signal
    _channel?.sink.add(jsonEncode({'action': 'end_turn'}));
    state = state.copyWith(state: VoiceState.transcribing);
  }

  /// Start recording and streaming audio
  Future<void> _startRecording() async {
    if (!await _recorder.hasPermission()) {
      state = state.copyWith(
        state: VoiceState.error,
        errorMessage: 'Microphone permission denied',
      );
      return;
    }
    
    state = state.copyWith(state: VoiceState.listening);
    
    // Record in WebM format (supported by OpenAI Whisper)
    final stream = await _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.opus,
        sampleRate: 16000,
        numChannels: 1,
      ),
    );
    
    // Stream audio chunks to WebSocket
    _recordSubscription = stream.listen((data) {
      if (_channel != null && state.state == VoiceState.listening) {
        _channel!.sink.add(data);
      }
    });
  }

  /// Handle WebSocket messages
  void _handleWebSocketMessage(dynamic message) async {
    if (message is Uint8List) {
      // Binary audio data - buffer for playback
      _audioBuffer.add(message);
      
      // Start playing if not already
      if (!_isPlayingAudio && state.state == VoiceState.processing) {
        state = state.copyWith(state: VoiceState.speaking);
        _playBufferedAudio();
      }
      return;
    }
    
    if (message is String) {
      try {
        final data = jsonDecode(message) as Map<String, dynamic>;
        
        switch (data['type']) {
          case 'authenticated':
            debugPrint('✅ Voice authenticated');
            break;
            
          case 'transcription':
            state = state.copyWith(
              transcription: data['text'] as String?,
            );
            break;
            
          case 'transcribing':
            state = state.copyWith(state: VoiceState.transcribing);
            break;
            
          case 'processing':
            state = state.copyWith(state: VoiceState.processing);
            break;
            
          case 'error':
            state = state.copyWith(
              state: VoiceState.error,
              errorMessage: data['message'] as String?,
            );
            // Auto-recover after error
            await Future.delayed(const Duration(seconds: 2));
            if (state.isConnected) {
              await _startRecording();
            }
            break;
        }
        
        if (data['status'] == 'turn_complete') {
          // Wait for audio to finish playing
          await Future.delayed(const Duration(milliseconds: 500));
          
          // Ready for next turn
          if (state.isConnected) {
            _audioBuffer.clear();
            await _startRecording();
          }
        }
      } catch (e) {
        debugPrint('⚠️ Error parsing WS message: $e');
      }
    }
  }

  /// Play buffered audio chunks
  Future<void> _playBufferedAudio() async {
    if (_audioBuffer.isEmpty) return;
    
    _isPlayingAudio = true;
    _player ??= AudioPlayer();
    
    try {
      // Combine all audio chunks
      final combined = Uint8List.fromList(
        _audioBuffer.expand((x) => x).toList()
      );
      
      // Create audio source from bytes
      await _player!.setAudioSource(
        _BytesAudioSource(combined),
      );
      
      await _player!.play();
      await _player!.processingStateStream.firstWhere(
        (state) => state == ProcessingState.completed,
      );
    } catch (e) {
      debugPrint('⚠️ Audio playback error: $e');
    } finally {
      _isPlayingAudio = false;
    }
  }

  void _handleWebSocketError(dynamic error) {
    debugPrint('❌ WebSocket error: $error');
    state = state.copyWith(
      state: VoiceState.error,
      errorMessage: 'Connection lost',
      isConnected: false,
    );
  }

  void _handleWebSocketDone() {
    debugPrint('🔌 WebSocket closed');
    state = state.copyWith(
      state: VoiceState.idle,
      isConnected: false,
    );
  }

  Future<void> _cleanup() async {
    _recordSubscription?.cancel();
    _wsSubscription?.cancel();
    await _recorder.stop();
    await _player?.dispose();
    await _channel?.sink.close();
    _channel = null;
    _player = null;
    _audioBuffer.clear();
    _isPlayingAudio = false;
  }
}

/// Audio source for playing bytes directly
class _BytesAudioSource extends StreamAudioSource {
  final Uint8List _bytes;

  _BytesAudioSource(this._bytes);

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    start ??= 0;
    end ??= _bytes.length;
    return StreamAudioResponse(
      sourceLength: _bytes.length,
      contentLength: end - start,
      offset: start,
      stream: Stream.value(Uint8List.sublistView(_bytes, start, end)),
      contentType: 'audio/mpeg',
    );
  }
}
