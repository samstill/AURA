// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'task.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SecretaryTask {
  int get id;
  String get title;
  String get status; // 'completed', 'failed', 'processing'
  String? get result;
  @JsonKey(name: 'is_read')
  bool get isRead;
  @JsonKey(name: 'created_at')
  DateTime get createdAt;

  /// Create a copy of SecretaryTask
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $SecretaryTaskCopyWith<SecretaryTask> get copyWith =>
      _$SecretaryTaskCopyWithImpl<SecretaryTask>(
          this as SecretaryTask, _$identity);

  /// Serializes this SecretaryTask to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is SecretaryTask &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.result, result) || other.result == result) &&
            (identical(other.isRead, isRead) || other.isRead == isRead) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, id, title, status, result, isRead, createdAt);

  @override
  String toString() {
    return 'SecretaryTask(id: $id, title: $title, status: $status, result: $result, isRead: $isRead, createdAt: $createdAt)';
  }
}

/// @nodoc
abstract mixin class $SecretaryTaskCopyWith<$Res> {
  factory $SecretaryTaskCopyWith(
          SecretaryTask value, $Res Function(SecretaryTask) _then) =
      _$SecretaryTaskCopyWithImpl;
  @useResult
  $Res call(
      {int id,
      String title,
      String status,
      String? result,
      @JsonKey(name: 'is_read') bool isRead,
      @JsonKey(name: 'created_at') DateTime createdAt});
}

/// @nodoc
class _$SecretaryTaskCopyWithImpl<$Res>
    implements $SecretaryTaskCopyWith<$Res> {
  _$SecretaryTaskCopyWithImpl(this._self, this._then);

  final SecretaryTask _self;
  final $Res Function(SecretaryTask) _then;

  /// Create a copy of SecretaryTask
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? status = null,
    Object? result = freezed,
    Object? isRead = null,
    Object? createdAt = null,
  }) {
    return _then(_self.copyWith(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as int,
      title: null == title
          ? _self.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
      result: freezed == result
          ? _self.result
          : result // ignore: cast_nullable_to_non_nullable
              as String?,
      isRead: null == isRead
          ? _self.isRead
          : isRead // ignore: cast_nullable_to_non_nullable
              as bool,
      createdAt: null == createdAt
          ? _self.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ));
  }
}

/// Adds pattern-matching-related methods to [SecretaryTask].
extension SecretaryTaskPatterns on SecretaryTask {
  /// A variant of `map` that fallback to returning `orElse`.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case _:
  ///     return orElse();
  /// }
  /// ```

  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>(
    TResult Function(_SecretaryTask value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _SecretaryTask() when $default != null:
        return $default(_that);
      case _:
        return orElse();
    }
  }

  /// A `switch`-like method, using callbacks.
  ///
  /// Callbacks receives the raw object, upcasted.
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case final Subclass2 value:
  ///     return ...;
  /// }
  /// ```

  @optionalTypeArgs
  TResult map<TResult extends Object?>(
    TResult Function(_SecretaryTask value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SecretaryTask():
        return $default(_that);
      case _:
        throw StateError('Unexpected subclass');
    }
  }

  /// A variant of `map` that fallback to returning `null`.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case _:
  ///     return null;
  /// }
  /// ```

  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>(
    TResult? Function(_SecretaryTask value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SecretaryTask() when $default != null:
        return $default(_that);
      case _:
        return null;
    }
  }

  /// A variant of `when` that fallback to an `orElse` callback.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case _:
  ///     return orElse();
  /// }
  /// ```

  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>(
    TResult Function(
            int id,
            String title,
            String status,
            String? result,
            @JsonKey(name: 'is_read') bool isRead,
            @JsonKey(name: 'created_at') DateTime createdAt)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _SecretaryTask() when $default != null:
        return $default(_that.id, _that.title, _that.status, _that.result,
            _that.isRead, _that.createdAt);
      case _:
        return orElse();
    }
  }

  /// A `switch`-like method, using callbacks.
  ///
  /// As opposed to `map`, this offers destructuring.
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case Subclass2(:final field2):
  ///     return ...;
  /// }
  /// ```

  @optionalTypeArgs
  TResult when<TResult extends Object?>(
    TResult Function(
            int id,
            String title,
            String status,
            String? result,
            @JsonKey(name: 'is_read') bool isRead,
            @JsonKey(name: 'created_at') DateTime createdAt)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SecretaryTask():
        return $default(_that.id, _that.title, _that.status, _that.result,
            _that.isRead, _that.createdAt);
      case _:
        throw StateError('Unexpected subclass');
    }
  }

  /// A variant of `when` that fallback to returning `null`
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case _:
  ///     return null;
  /// }
  /// ```

  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>(
    TResult? Function(
            int id,
            String title,
            String status,
            String? result,
            @JsonKey(name: 'is_read') bool isRead,
            @JsonKey(name: 'created_at') DateTime createdAt)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SecretaryTask() when $default != null:
        return $default(_that.id, _that.title, _that.status, _that.result,
            _that.isRead, _that.createdAt);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _SecretaryTask implements SecretaryTask {
  const _SecretaryTask(
      {required this.id,
      required this.title,
      required this.status,
      this.result,
      @JsonKey(name: 'is_read') this.isRead = false,
      @JsonKey(name: 'created_at') required this.createdAt});
  factory _SecretaryTask.fromJson(Map<String, dynamic> json) =>
      _$SecretaryTaskFromJson(json);

  @override
  final int id;
  @override
  final String title;
  @override
  final String status;
// 'completed', 'failed', 'processing'
  @override
  final String? result;
  @override
  @JsonKey(name: 'is_read')
  final bool isRead;
  @override
  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  /// Create a copy of SecretaryTask
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$SecretaryTaskCopyWith<_SecretaryTask> get copyWith =>
      __$SecretaryTaskCopyWithImpl<_SecretaryTask>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$SecretaryTaskToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _SecretaryTask &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.result, result) || other.result == result) &&
            (identical(other.isRead, isRead) || other.isRead == isRead) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, id, title, status, result, isRead, createdAt);

  @override
  String toString() {
    return 'SecretaryTask(id: $id, title: $title, status: $status, result: $result, isRead: $isRead, createdAt: $createdAt)';
  }
}

/// @nodoc
abstract mixin class _$SecretaryTaskCopyWith<$Res>
    implements $SecretaryTaskCopyWith<$Res> {
  factory _$SecretaryTaskCopyWith(
          _SecretaryTask value, $Res Function(_SecretaryTask) _then) =
      __$SecretaryTaskCopyWithImpl;
  @override
  @useResult
  $Res call(
      {int id,
      String title,
      String status,
      String? result,
      @JsonKey(name: 'is_read') bool isRead,
      @JsonKey(name: 'created_at') DateTime createdAt});
}

/// @nodoc
class __$SecretaryTaskCopyWithImpl<$Res>
    implements _$SecretaryTaskCopyWith<$Res> {
  __$SecretaryTaskCopyWithImpl(this._self, this._then);

  final _SecretaryTask _self;
  final $Res Function(_SecretaryTask) _then;

  /// Create a copy of SecretaryTask
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? status = null,
    Object? result = freezed,
    Object? isRead = null,
    Object? createdAt = null,
  }) {
    return _then(_SecretaryTask(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as int,
      title: null == title
          ? _self.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
      result: freezed == result
          ? _self.result
          : result // ignore: cast_nullable_to_non_nullable
              as String?,
      isRead: null == isRead
          ? _self.isRead
          : isRead // ignore: cast_nullable_to_non_nullable
              as bool,
      createdAt: null == createdAt
          ? _self.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ));
  }
}

// dart format on
