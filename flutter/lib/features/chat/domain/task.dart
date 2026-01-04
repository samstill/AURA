// ignore_for_file: invalid_annotation_target
import 'package:freezed_annotation/freezed_annotation.dart';

part 'task.freezed.dart';
part 'task.g.dart';

@freezed
abstract class SecretaryTask with _$SecretaryTask {
  const factory SecretaryTask({
    required int id,
    required String title,
    required String status, // 'completed', 'failed', 'processing'
    String? result,
    @JsonKey(name: 'is_read') @Default(false) bool isRead,
    @JsonKey(name: 'created_at') required DateTime createdAt,
  }) = _SecretaryTask;

  factory SecretaryTask.fromJson(Map<String, dynamic> json) =>
      _$SecretaryTaskFromJson(json);
}
