// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_state.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$AuthUserImpl _$$AuthUserImplFromJson(Map<String, dynamic> json) =>
    _$AuthUserImpl(
      id: json['id'] as String,
      email: json['email'] as String,
      emailVerified: json['emailVerified'] as bool? ?? false,
      name: json['name'] as String,
      username: json['username'] as String,
      groups: (json['groups'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
    );

Map<String, dynamic> _$$AuthUserImplToJson(_$AuthUserImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'email': instance.email,
      'emailVerified': instance.emailVerified,
      'name': instance.name,
      'username': instance.username,
      'groups': instance.groups,
    };
