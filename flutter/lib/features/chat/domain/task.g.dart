// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_SecretaryTask _$SecretaryTaskFromJson(Map<String, dynamic> json) =>
    _SecretaryTask(
      id: (json['id'] as num).toInt(),
      title: json['title'] as String,
      status: json['status'] as String,
      result: json['result'] as String?,
      isRead: json['is_read'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );

Map<String, dynamic> _$SecretaryTaskToJson(_SecretaryTask instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'status': instance.status,
      'result': instance.result,
      'is_read': instance.isRead,
      'created_at': instance.createdAt.toIso8601String(),
    };
