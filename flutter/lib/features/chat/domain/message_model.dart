/// Project Aura - Message Model
/// =============================
/// Immutable message model using freezed.

import 'package:freezed_annotation/freezed_annotation.dart';

part 'message_model.freezed.dart';
part 'message_model.g.dart';

@freezed
class Message with _$Message {
  const factory Message({
    required String id,
    required String text,
    required bool isUser, // true = User, false = Aura
    required DateTime timestamp,
    @Default(false) bool isThinking, // For UI loading states
    String? error,
  }) = _Message;

  factory Message.fromJson(Map<String, dynamic> json) => _$MessageFromJson(json);
}
