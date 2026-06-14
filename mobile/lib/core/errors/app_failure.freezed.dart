// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'app_failure.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$AppFailure {
  String get message => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String message) unexpected,
    required TResult Function(String message) notFound,
    required TResult Function(String message) unauthorized,
    required TResult Function(String message) validation,
    required TResult Function(String message) networkError,
    required TResult Function(String message) consentRequired,
    required TResult Function(String message) conflict,
    required TResult Function(String message) forbidden,
    required TResult Function(String code, String message) businessRule,
    required TResult Function(String message) serviceUnavailable,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String message)? unexpected,
    TResult? Function(String message)? notFound,
    TResult? Function(String message)? unauthorized,
    TResult? Function(String message)? validation,
    TResult? Function(String message)? networkError,
    TResult? Function(String message)? consentRequired,
    TResult? Function(String message)? conflict,
    TResult? Function(String message)? forbidden,
    TResult? Function(String code, String message)? businessRule,
    TResult? Function(String message)? serviceUnavailable,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String message)? unexpected,
    TResult Function(String message)? notFound,
    TResult Function(String message)? unauthorized,
    TResult Function(String message)? validation,
    TResult Function(String message)? networkError,
    TResult Function(String message)? consentRequired,
    TResult Function(String message)? conflict,
    TResult Function(String message)? forbidden,
    TResult Function(String code, String message)? businessRule,
    TResult Function(String message)? serviceUnavailable,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_Unexpected value) unexpected,
    required TResult Function(_NotFound value) notFound,
    required TResult Function(_Unauthorized value) unauthorized,
    required TResult Function(_Validation value) validation,
    required TResult Function(_NetworkError value) networkError,
    required TResult Function(_ConsentRequired value) consentRequired,
    required TResult Function(_Conflict value) conflict,
    required TResult Function(_Forbidden value) forbidden,
    required TResult Function(_BusinessRule value) businessRule,
    required TResult Function(_ServiceUnavailable value) serviceUnavailable,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_Unexpected value)? unexpected,
    TResult? Function(_NotFound value)? notFound,
    TResult? Function(_Unauthorized value)? unauthorized,
    TResult? Function(_Validation value)? validation,
    TResult? Function(_NetworkError value)? networkError,
    TResult? Function(_ConsentRequired value)? consentRequired,
    TResult? Function(_Conflict value)? conflict,
    TResult? Function(_Forbidden value)? forbidden,
    TResult? Function(_BusinessRule value)? businessRule,
    TResult? Function(_ServiceUnavailable value)? serviceUnavailable,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_Unexpected value)? unexpected,
    TResult Function(_NotFound value)? notFound,
    TResult Function(_Unauthorized value)? unauthorized,
    TResult Function(_Validation value)? validation,
    TResult Function(_NetworkError value)? networkError,
    TResult Function(_ConsentRequired value)? consentRequired,
    TResult Function(_Conflict value)? conflict,
    TResult Function(_Forbidden value)? forbidden,
    TResult Function(_BusinessRule value)? businessRule,
    TResult Function(_ServiceUnavailable value)? serviceUnavailable,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;

  /// Create a copy of AppFailure
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AppFailureCopyWith<AppFailure> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AppFailureCopyWith<$Res> {
  factory $AppFailureCopyWith(
          AppFailure value, $Res Function(AppFailure) then) =
      _$AppFailureCopyWithImpl<$Res, AppFailure>;
  @useResult
  $Res call({String message});
}

/// @nodoc
class _$AppFailureCopyWithImpl<$Res, $Val extends AppFailure>
    implements $AppFailureCopyWith<$Res> {
  _$AppFailureCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AppFailure
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? message = null,
  }) {
    return _then(_value.copyWith(
      message: null == message
          ? _value.message
          : message // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$UnexpectedImplCopyWith<$Res>
    implements $AppFailureCopyWith<$Res> {
  factory _$$UnexpectedImplCopyWith(
          _$UnexpectedImpl value, $Res Function(_$UnexpectedImpl) then) =
      __$$UnexpectedImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String message});
}

/// @nodoc
class __$$UnexpectedImplCopyWithImpl<$Res>
    extends _$AppFailureCopyWithImpl<$Res, _$UnexpectedImpl>
    implements _$$UnexpectedImplCopyWith<$Res> {
  __$$UnexpectedImplCopyWithImpl(
      _$UnexpectedImpl _value, $Res Function(_$UnexpectedImpl) _then)
      : super(_value, _then);

  /// Create a copy of AppFailure
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? message = null,
  }) {
    return _then(_$UnexpectedImpl(
      message: null == message
          ? _value.message
          : message // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc

class _$UnexpectedImpl implements _Unexpected {
  const _$UnexpectedImpl({required this.message});

  @override
  final String message;

  @override
  String toString() {
    return 'AppFailure.unexpected(message: $message)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$UnexpectedImpl &&
            (identical(other.message, message) || other.message == message));
  }

  @override
  int get hashCode => Object.hash(runtimeType, message);

  /// Create a copy of AppFailure
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$UnexpectedImplCopyWith<_$UnexpectedImpl> get copyWith =>
      __$$UnexpectedImplCopyWithImpl<_$UnexpectedImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String message) unexpected,
    required TResult Function(String message) notFound,
    required TResult Function(String message) unauthorized,
    required TResult Function(String message) validation,
    required TResult Function(String message) networkError,
    required TResult Function(String message) consentRequired,
    required TResult Function(String message) conflict,
    required TResult Function(String message) forbidden,
    required TResult Function(String code, String message) businessRule,
    required TResult Function(String message) serviceUnavailable,
  }) {
    return unexpected(message);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String message)? unexpected,
    TResult? Function(String message)? notFound,
    TResult? Function(String message)? unauthorized,
    TResult? Function(String message)? validation,
    TResult? Function(String message)? networkError,
    TResult? Function(String message)? consentRequired,
    TResult? Function(String message)? conflict,
    TResult? Function(String message)? forbidden,
    TResult? Function(String code, String message)? businessRule,
    TResult? Function(String message)? serviceUnavailable,
  }) {
    return unexpected?.call(message);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String message)? unexpected,
    TResult Function(String message)? notFound,
    TResult Function(String message)? unauthorized,
    TResult Function(String message)? validation,
    TResult Function(String message)? networkError,
    TResult Function(String message)? consentRequired,
    TResult Function(String message)? conflict,
    TResult Function(String message)? forbidden,
    TResult Function(String code, String message)? businessRule,
    TResult Function(String message)? serviceUnavailable,
    required TResult orElse(),
  }) {
    if (unexpected != null) {
      return unexpected(message);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_Unexpected value) unexpected,
    required TResult Function(_NotFound value) notFound,
    required TResult Function(_Unauthorized value) unauthorized,
    required TResult Function(_Validation value) validation,
    required TResult Function(_NetworkError value) networkError,
    required TResult Function(_ConsentRequired value) consentRequired,
    required TResult Function(_Conflict value) conflict,
    required TResult Function(_Forbidden value) forbidden,
    required TResult Function(_BusinessRule value) businessRule,
    required TResult Function(_ServiceUnavailable value) serviceUnavailable,
  }) {
    return unexpected(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_Unexpected value)? unexpected,
    TResult? Function(_NotFound value)? notFound,
    TResult? Function(_Unauthorized value)? unauthorized,
    TResult? Function(_Validation value)? validation,
    TResult? Function(_NetworkError value)? networkError,
    TResult? Function(_ConsentRequired value)? consentRequired,
    TResult? Function(_Conflict value)? conflict,
    TResult? Function(_Forbidden value)? forbidden,
    TResult? Function(_BusinessRule value)? businessRule,
    TResult? Function(_ServiceUnavailable value)? serviceUnavailable,
  }) {
    return unexpected?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_Unexpected value)? unexpected,
    TResult Function(_NotFound value)? notFound,
    TResult Function(_Unauthorized value)? unauthorized,
    TResult Function(_Validation value)? validation,
    TResult Function(_NetworkError value)? networkError,
    TResult Function(_ConsentRequired value)? consentRequired,
    TResult Function(_Conflict value)? conflict,
    TResult Function(_Forbidden value)? forbidden,
    TResult Function(_BusinessRule value)? businessRule,
    TResult Function(_ServiceUnavailable value)? serviceUnavailable,
    required TResult orElse(),
  }) {
    if (unexpected != null) {
      return unexpected(this);
    }
    return orElse();
  }
}

abstract class _Unexpected implements AppFailure {
  const factory _Unexpected({required final String message}) = _$UnexpectedImpl;

  @override
  String get message;

  /// Create a copy of AppFailure
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$UnexpectedImplCopyWith<_$UnexpectedImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$NotFoundImplCopyWith<$Res>
    implements $AppFailureCopyWith<$Res> {
  factory _$$NotFoundImplCopyWith(
          _$NotFoundImpl value, $Res Function(_$NotFoundImpl) then) =
      __$$NotFoundImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String message});
}

/// @nodoc
class __$$NotFoundImplCopyWithImpl<$Res>
    extends _$AppFailureCopyWithImpl<$Res, _$NotFoundImpl>
    implements _$$NotFoundImplCopyWith<$Res> {
  __$$NotFoundImplCopyWithImpl(
      _$NotFoundImpl _value, $Res Function(_$NotFoundImpl) _then)
      : super(_value, _then);

  /// Create a copy of AppFailure
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? message = null,
  }) {
    return _then(_$NotFoundImpl(
      message: null == message
          ? _value.message
          : message // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc

class _$NotFoundImpl implements _NotFound {
  const _$NotFoundImpl({required this.message});

  @override
  final String message;

  @override
  String toString() {
    return 'AppFailure.notFound(message: $message)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$NotFoundImpl &&
            (identical(other.message, message) || other.message == message));
  }

  @override
  int get hashCode => Object.hash(runtimeType, message);

  /// Create a copy of AppFailure
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$NotFoundImplCopyWith<_$NotFoundImpl> get copyWith =>
      __$$NotFoundImplCopyWithImpl<_$NotFoundImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String message) unexpected,
    required TResult Function(String message) notFound,
    required TResult Function(String message) unauthorized,
    required TResult Function(String message) validation,
    required TResult Function(String message) networkError,
    required TResult Function(String message) consentRequired,
    required TResult Function(String message) conflict,
    required TResult Function(String message) forbidden,
    required TResult Function(String code, String message) businessRule,
    required TResult Function(String message) serviceUnavailable,
  }) {
    return notFound(message);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String message)? unexpected,
    TResult? Function(String message)? notFound,
    TResult? Function(String message)? unauthorized,
    TResult? Function(String message)? validation,
    TResult? Function(String message)? networkError,
    TResult? Function(String message)? consentRequired,
    TResult? Function(String message)? conflict,
    TResult? Function(String message)? forbidden,
    TResult? Function(String code, String message)? businessRule,
    TResult? Function(String message)? serviceUnavailable,
  }) {
    return notFound?.call(message);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String message)? unexpected,
    TResult Function(String message)? notFound,
    TResult Function(String message)? unauthorized,
    TResult Function(String message)? validation,
    TResult Function(String message)? networkError,
    TResult Function(String message)? consentRequired,
    TResult Function(String message)? conflict,
    TResult Function(String message)? forbidden,
    TResult Function(String code, String message)? businessRule,
    TResult Function(String message)? serviceUnavailable,
    required TResult orElse(),
  }) {
    if (notFound != null) {
      return notFound(message);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_Unexpected value) unexpected,
    required TResult Function(_NotFound value) notFound,
    required TResult Function(_Unauthorized value) unauthorized,
    required TResult Function(_Validation value) validation,
    required TResult Function(_NetworkError value) networkError,
    required TResult Function(_ConsentRequired value) consentRequired,
    required TResult Function(_Conflict value) conflict,
    required TResult Function(_Forbidden value) forbidden,
    required TResult Function(_BusinessRule value) businessRule,
    required TResult Function(_ServiceUnavailable value) serviceUnavailable,
  }) {
    return notFound(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_Unexpected value)? unexpected,
    TResult? Function(_NotFound value)? notFound,
    TResult? Function(_Unauthorized value)? unauthorized,
    TResult? Function(_Validation value)? validation,
    TResult? Function(_NetworkError value)? networkError,
    TResult? Function(_ConsentRequired value)? consentRequired,
    TResult? Function(_Conflict value)? conflict,
    TResult? Function(_Forbidden value)? forbidden,
    TResult? Function(_BusinessRule value)? businessRule,
    TResult? Function(_ServiceUnavailable value)? serviceUnavailable,
  }) {
    return notFound?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_Unexpected value)? unexpected,
    TResult Function(_NotFound value)? notFound,
    TResult Function(_Unauthorized value)? unauthorized,
    TResult Function(_Validation value)? validation,
    TResult Function(_NetworkError value)? networkError,
    TResult Function(_ConsentRequired value)? consentRequired,
    TResult Function(_Conflict value)? conflict,
    TResult Function(_Forbidden value)? forbidden,
    TResult Function(_BusinessRule value)? businessRule,
    TResult Function(_ServiceUnavailable value)? serviceUnavailable,
    required TResult orElse(),
  }) {
    if (notFound != null) {
      return notFound(this);
    }
    return orElse();
  }
}

abstract class _NotFound implements AppFailure {
  const factory _NotFound({required final String message}) = _$NotFoundImpl;

  @override
  String get message;

  /// Create a copy of AppFailure
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$NotFoundImplCopyWith<_$NotFoundImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$UnauthorizedImplCopyWith<$Res>
    implements $AppFailureCopyWith<$Res> {
  factory _$$UnauthorizedImplCopyWith(
          _$UnauthorizedImpl value, $Res Function(_$UnauthorizedImpl) then) =
      __$$UnauthorizedImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String message});
}

/// @nodoc
class __$$UnauthorizedImplCopyWithImpl<$Res>
    extends _$AppFailureCopyWithImpl<$Res, _$UnauthorizedImpl>
    implements _$$UnauthorizedImplCopyWith<$Res> {
  __$$UnauthorizedImplCopyWithImpl(
      _$UnauthorizedImpl _value, $Res Function(_$UnauthorizedImpl) _then)
      : super(_value, _then);

  /// Create a copy of AppFailure
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? message = null,
  }) {
    return _then(_$UnauthorizedImpl(
      message: null == message
          ? _value.message
          : message // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc

class _$UnauthorizedImpl implements _Unauthorized {
  const _$UnauthorizedImpl({required this.message});

  @override
  final String message;

  @override
  String toString() {
    return 'AppFailure.unauthorized(message: $message)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$UnauthorizedImpl &&
            (identical(other.message, message) || other.message == message));
  }

  @override
  int get hashCode => Object.hash(runtimeType, message);

  /// Create a copy of AppFailure
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$UnauthorizedImplCopyWith<_$UnauthorizedImpl> get copyWith =>
      __$$UnauthorizedImplCopyWithImpl<_$UnauthorizedImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String message) unexpected,
    required TResult Function(String message) notFound,
    required TResult Function(String message) unauthorized,
    required TResult Function(String message) validation,
    required TResult Function(String message) networkError,
    required TResult Function(String message) consentRequired,
    required TResult Function(String message) conflict,
    required TResult Function(String message) forbidden,
    required TResult Function(String code, String message) businessRule,
    required TResult Function(String message) serviceUnavailable,
  }) {
    return unauthorized(message);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String message)? unexpected,
    TResult? Function(String message)? notFound,
    TResult? Function(String message)? unauthorized,
    TResult? Function(String message)? validation,
    TResult? Function(String message)? networkError,
    TResult? Function(String message)? consentRequired,
    TResult? Function(String message)? conflict,
    TResult? Function(String message)? forbidden,
    TResult? Function(String code, String message)? businessRule,
    TResult? Function(String message)? serviceUnavailable,
  }) {
    return unauthorized?.call(message);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String message)? unexpected,
    TResult Function(String message)? notFound,
    TResult Function(String message)? unauthorized,
    TResult Function(String message)? validation,
    TResult Function(String message)? networkError,
    TResult Function(String message)? consentRequired,
    TResult Function(String message)? conflict,
    TResult Function(String message)? forbidden,
    TResult Function(String code, String message)? businessRule,
    TResult Function(String message)? serviceUnavailable,
    required TResult orElse(),
  }) {
    if (unauthorized != null) {
      return unauthorized(message);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_Unexpected value) unexpected,
    required TResult Function(_NotFound value) notFound,
    required TResult Function(_Unauthorized value) unauthorized,
    required TResult Function(_Validation value) validation,
    required TResult Function(_NetworkError value) networkError,
    required TResult Function(_ConsentRequired value) consentRequired,
    required TResult Function(_Conflict value) conflict,
    required TResult Function(_Forbidden value) forbidden,
    required TResult Function(_BusinessRule value) businessRule,
    required TResult Function(_ServiceUnavailable value) serviceUnavailable,
  }) {
    return unauthorized(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_Unexpected value)? unexpected,
    TResult? Function(_NotFound value)? notFound,
    TResult? Function(_Unauthorized value)? unauthorized,
    TResult? Function(_Validation value)? validation,
    TResult? Function(_NetworkError value)? networkError,
    TResult? Function(_ConsentRequired value)? consentRequired,
    TResult? Function(_Conflict value)? conflict,
    TResult? Function(_Forbidden value)? forbidden,
    TResult? Function(_BusinessRule value)? businessRule,
    TResult? Function(_ServiceUnavailable value)? serviceUnavailable,
  }) {
    return unauthorized?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_Unexpected value)? unexpected,
    TResult Function(_NotFound value)? notFound,
    TResult Function(_Unauthorized value)? unauthorized,
    TResult Function(_Validation value)? validation,
    TResult Function(_NetworkError value)? networkError,
    TResult Function(_ConsentRequired value)? consentRequired,
    TResult Function(_Conflict value)? conflict,
    TResult Function(_Forbidden value)? forbidden,
    TResult Function(_BusinessRule value)? businessRule,
    TResult Function(_ServiceUnavailable value)? serviceUnavailable,
    required TResult orElse(),
  }) {
    if (unauthorized != null) {
      return unauthorized(this);
    }
    return orElse();
  }
}

abstract class _Unauthorized implements AppFailure {
  const factory _Unauthorized({required final String message}) =
      _$UnauthorizedImpl;

  @override
  String get message;

  /// Create a copy of AppFailure
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$UnauthorizedImplCopyWith<_$UnauthorizedImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$ValidationImplCopyWith<$Res>
    implements $AppFailureCopyWith<$Res> {
  factory _$$ValidationImplCopyWith(
          _$ValidationImpl value, $Res Function(_$ValidationImpl) then) =
      __$$ValidationImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String message});
}

/// @nodoc
class __$$ValidationImplCopyWithImpl<$Res>
    extends _$AppFailureCopyWithImpl<$Res, _$ValidationImpl>
    implements _$$ValidationImplCopyWith<$Res> {
  __$$ValidationImplCopyWithImpl(
      _$ValidationImpl _value, $Res Function(_$ValidationImpl) _then)
      : super(_value, _then);

  /// Create a copy of AppFailure
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? message = null,
  }) {
    return _then(_$ValidationImpl(
      message: null == message
          ? _value.message
          : message // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc

class _$ValidationImpl implements _Validation {
  const _$ValidationImpl({required this.message});

  @override
  final String message;

  @override
  String toString() {
    return 'AppFailure.validation(message: $message)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ValidationImpl &&
            (identical(other.message, message) || other.message == message));
  }

  @override
  int get hashCode => Object.hash(runtimeType, message);

  /// Create a copy of AppFailure
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ValidationImplCopyWith<_$ValidationImpl> get copyWith =>
      __$$ValidationImplCopyWithImpl<_$ValidationImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String message) unexpected,
    required TResult Function(String message) notFound,
    required TResult Function(String message) unauthorized,
    required TResult Function(String message) validation,
    required TResult Function(String message) networkError,
    required TResult Function(String message) consentRequired,
    required TResult Function(String message) conflict,
    required TResult Function(String message) forbidden,
    required TResult Function(String code, String message) businessRule,
    required TResult Function(String message) serviceUnavailable,
  }) {
    return validation(message);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String message)? unexpected,
    TResult? Function(String message)? notFound,
    TResult? Function(String message)? unauthorized,
    TResult? Function(String message)? validation,
    TResult? Function(String message)? networkError,
    TResult? Function(String message)? consentRequired,
    TResult? Function(String message)? conflict,
    TResult? Function(String message)? forbidden,
    TResult? Function(String code, String message)? businessRule,
    TResult? Function(String message)? serviceUnavailable,
  }) {
    return validation?.call(message);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String message)? unexpected,
    TResult Function(String message)? notFound,
    TResult Function(String message)? unauthorized,
    TResult Function(String message)? validation,
    TResult Function(String message)? networkError,
    TResult Function(String message)? consentRequired,
    TResult Function(String message)? conflict,
    TResult Function(String message)? forbidden,
    TResult Function(String code, String message)? businessRule,
    TResult Function(String message)? serviceUnavailable,
    required TResult orElse(),
  }) {
    if (validation != null) {
      return validation(message);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_Unexpected value) unexpected,
    required TResult Function(_NotFound value) notFound,
    required TResult Function(_Unauthorized value) unauthorized,
    required TResult Function(_Validation value) validation,
    required TResult Function(_NetworkError value) networkError,
    required TResult Function(_ConsentRequired value) consentRequired,
    required TResult Function(_Conflict value) conflict,
    required TResult Function(_Forbidden value) forbidden,
    required TResult Function(_BusinessRule value) businessRule,
    required TResult Function(_ServiceUnavailable value) serviceUnavailable,
  }) {
    return validation(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_Unexpected value)? unexpected,
    TResult? Function(_NotFound value)? notFound,
    TResult? Function(_Unauthorized value)? unauthorized,
    TResult? Function(_Validation value)? validation,
    TResult? Function(_NetworkError value)? networkError,
    TResult? Function(_ConsentRequired value)? consentRequired,
    TResult? Function(_Conflict value)? conflict,
    TResult? Function(_Forbidden value)? forbidden,
    TResult? Function(_BusinessRule value)? businessRule,
    TResult? Function(_ServiceUnavailable value)? serviceUnavailable,
  }) {
    return validation?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_Unexpected value)? unexpected,
    TResult Function(_NotFound value)? notFound,
    TResult Function(_Unauthorized value)? unauthorized,
    TResult Function(_Validation value)? validation,
    TResult Function(_NetworkError value)? networkError,
    TResult Function(_ConsentRequired value)? consentRequired,
    TResult Function(_Conflict value)? conflict,
    TResult Function(_Forbidden value)? forbidden,
    TResult Function(_BusinessRule value)? businessRule,
    TResult Function(_ServiceUnavailable value)? serviceUnavailable,
    required TResult orElse(),
  }) {
    if (validation != null) {
      return validation(this);
    }
    return orElse();
  }
}

abstract class _Validation implements AppFailure {
  const factory _Validation({required final String message}) = _$ValidationImpl;

  @override
  String get message;

  /// Create a copy of AppFailure
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ValidationImplCopyWith<_$ValidationImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$NetworkErrorImplCopyWith<$Res>
    implements $AppFailureCopyWith<$Res> {
  factory _$$NetworkErrorImplCopyWith(
          _$NetworkErrorImpl value, $Res Function(_$NetworkErrorImpl) then) =
      __$$NetworkErrorImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String message});
}

/// @nodoc
class __$$NetworkErrorImplCopyWithImpl<$Res>
    extends _$AppFailureCopyWithImpl<$Res, _$NetworkErrorImpl>
    implements _$$NetworkErrorImplCopyWith<$Res> {
  __$$NetworkErrorImplCopyWithImpl(
      _$NetworkErrorImpl _value, $Res Function(_$NetworkErrorImpl) _then)
      : super(_value, _then);

  /// Create a copy of AppFailure
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? message = null,
  }) {
    return _then(_$NetworkErrorImpl(
      message: null == message
          ? _value.message
          : message // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc

class _$NetworkErrorImpl implements _NetworkError {
  const _$NetworkErrorImpl({required this.message});

  @override
  final String message;

  @override
  String toString() {
    return 'AppFailure.networkError(message: $message)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$NetworkErrorImpl &&
            (identical(other.message, message) || other.message == message));
  }

  @override
  int get hashCode => Object.hash(runtimeType, message);

  /// Create a copy of AppFailure
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$NetworkErrorImplCopyWith<_$NetworkErrorImpl> get copyWith =>
      __$$NetworkErrorImplCopyWithImpl<_$NetworkErrorImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String message) unexpected,
    required TResult Function(String message) notFound,
    required TResult Function(String message) unauthorized,
    required TResult Function(String message) validation,
    required TResult Function(String message) networkError,
    required TResult Function(String message) consentRequired,
    required TResult Function(String message) conflict,
    required TResult Function(String message) forbidden,
    required TResult Function(String code, String message) businessRule,
    required TResult Function(String message) serviceUnavailable,
  }) {
    return networkError(message);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String message)? unexpected,
    TResult? Function(String message)? notFound,
    TResult? Function(String message)? unauthorized,
    TResult? Function(String message)? validation,
    TResult? Function(String message)? networkError,
    TResult? Function(String message)? consentRequired,
    TResult? Function(String message)? conflict,
    TResult? Function(String message)? forbidden,
    TResult? Function(String code, String message)? businessRule,
    TResult? Function(String message)? serviceUnavailable,
  }) {
    return networkError?.call(message);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String message)? unexpected,
    TResult Function(String message)? notFound,
    TResult Function(String message)? unauthorized,
    TResult Function(String message)? validation,
    TResult Function(String message)? networkError,
    TResult Function(String message)? consentRequired,
    TResult Function(String message)? conflict,
    TResult Function(String message)? forbidden,
    TResult Function(String code, String message)? businessRule,
    TResult Function(String message)? serviceUnavailable,
    required TResult orElse(),
  }) {
    if (networkError != null) {
      return networkError(message);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_Unexpected value) unexpected,
    required TResult Function(_NotFound value) notFound,
    required TResult Function(_Unauthorized value) unauthorized,
    required TResult Function(_Validation value) validation,
    required TResult Function(_NetworkError value) networkError,
    required TResult Function(_ConsentRequired value) consentRequired,
    required TResult Function(_Conflict value) conflict,
    required TResult Function(_Forbidden value) forbidden,
    required TResult Function(_BusinessRule value) businessRule,
    required TResult Function(_ServiceUnavailable value) serviceUnavailable,
  }) {
    return networkError(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_Unexpected value)? unexpected,
    TResult? Function(_NotFound value)? notFound,
    TResult? Function(_Unauthorized value)? unauthorized,
    TResult? Function(_Validation value)? validation,
    TResult? Function(_NetworkError value)? networkError,
    TResult? Function(_ConsentRequired value)? consentRequired,
    TResult? Function(_Conflict value)? conflict,
    TResult? Function(_Forbidden value)? forbidden,
    TResult? Function(_BusinessRule value)? businessRule,
    TResult? Function(_ServiceUnavailable value)? serviceUnavailable,
  }) {
    return networkError?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_Unexpected value)? unexpected,
    TResult Function(_NotFound value)? notFound,
    TResult Function(_Unauthorized value)? unauthorized,
    TResult Function(_Validation value)? validation,
    TResult Function(_NetworkError value)? networkError,
    TResult Function(_ConsentRequired value)? consentRequired,
    TResult Function(_Conflict value)? conflict,
    TResult Function(_Forbidden value)? forbidden,
    TResult Function(_BusinessRule value)? businessRule,
    TResult Function(_ServiceUnavailable value)? serviceUnavailable,
    required TResult orElse(),
  }) {
    if (networkError != null) {
      return networkError(this);
    }
    return orElse();
  }
}

abstract class _NetworkError implements AppFailure {
  const factory _NetworkError({required final String message}) =
      _$NetworkErrorImpl;

  @override
  String get message;

  /// Create a copy of AppFailure
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$NetworkErrorImplCopyWith<_$NetworkErrorImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$ConsentRequiredImplCopyWith<$Res>
    implements $AppFailureCopyWith<$Res> {
  factory _$$ConsentRequiredImplCopyWith(_$ConsentRequiredImpl value,
          $Res Function(_$ConsentRequiredImpl) then) =
      __$$ConsentRequiredImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String message});
}

/// @nodoc
class __$$ConsentRequiredImplCopyWithImpl<$Res>
    extends _$AppFailureCopyWithImpl<$Res, _$ConsentRequiredImpl>
    implements _$$ConsentRequiredImplCopyWith<$Res> {
  __$$ConsentRequiredImplCopyWithImpl(
      _$ConsentRequiredImpl _value, $Res Function(_$ConsentRequiredImpl) _then)
      : super(_value, _then);

  /// Create a copy of AppFailure
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? message = null,
  }) {
    return _then(_$ConsentRequiredImpl(
      message: null == message
          ? _value.message
          : message // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc

class _$ConsentRequiredImpl implements _ConsentRequired {
  const _$ConsentRequiredImpl({required this.message});

  @override
  final String message;

  @override
  String toString() {
    return 'AppFailure.consentRequired(message: $message)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ConsentRequiredImpl &&
            (identical(other.message, message) || other.message == message));
  }

  @override
  int get hashCode => Object.hash(runtimeType, message);

  /// Create a copy of AppFailure
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ConsentRequiredImplCopyWith<_$ConsentRequiredImpl> get copyWith =>
      __$$ConsentRequiredImplCopyWithImpl<_$ConsentRequiredImpl>(
          this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String message) unexpected,
    required TResult Function(String message) notFound,
    required TResult Function(String message) unauthorized,
    required TResult Function(String message) validation,
    required TResult Function(String message) networkError,
    required TResult Function(String message) consentRequired,
    required TResult Function(String message) conflict,
    required TResult Function(String message) forbidden,
    required TResult Function(String code, String message) businessRule,
    required TResult Function(String message) serviceUnavailable,
  }) {
    return consentRequired(message);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String message)? unexpected,
    TResult? Function(String message)? notFound,
    TResult? Function(String message)? unauthorized,
    TResult? Function(String message)? validation,
    TResult? Function(String message)? networkError,
    TResult? Function(String message)? consentRequired,
    TResult? Function(String message)? conflict,
    TResult? Function(String message)? forbidden,
    TResult? Function(String code, String message)? businessRule,
    TResult? Function(String message)? serviceUnavailable,
  }) {
    return consentRequired?.call(message);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String message)? unexpected,
    TResult Function(String message)? notFound,
    TResult Function(String message)? unauthorized,
    TResult Function(String message)? validation,
    TResult Function(String message)? networkError,
    TResult Function(String message)? consentRequired,
    TResult Function(String message)? conflict,
    TResult Function(String message)? forbidden,
    TResult Function(String code, String message)? businessRule,
    TResult Function(String message)? serviceUnavailable,
    required TResult orElse(),
  }) {
    if (consentRequired != null) {
      return consentRequired(message);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_Unexpected value) unexpected,
    required TResult Function(_NotFound value) notFound,
    required TResult Function(_Unauthorized value) unauthorized,
    required TResult Function(_Validation value) validation,
    required TResult Function(_NetworkError value) networkError,
    required TResult Function(_ConsentRequired value) consentRequired,
    required TResult Function(_Conflict value) conflict,
    required TResult Function(_Forbidden value) forbidden,
    required TResult Function(_BusinessRule value) businessRule,
    required TResult Function(_ServiceUnavailable value) serviceUnavailable,
  }) {
    return consentRequired(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_Unexpected value)? unexpected,
    TResult? Function(_NotFound value)? notFound,
    TResult? Function(_Unauthorized value)? unauthorized,
    TResult? Function(_Validation value)? validation,
    TResult? Function(_NetworkError value)? networkError,
    TResult? Function(_ConsentRequired value)? consentRequired,
    TResult? Function(_Conflict value)? conflict,
    TResult? Function(_Forbidden value)? forbidden,
    TResult? Function(_BusinessRule value)? businessRule,
    TResult? Function(_ServiceUnavailable value)? serviceUnavailable,
  }) {
    return consentRequired?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_Unexpected value)? unexpected,
    TResult Function(_NotFound value)? notFound,
    TResult Function(_Unauthorized value)? unauthorized,
    TResult Function(_Validation value)? validation,
    TResult Function(_NetworkError value)? networkError,
    TResult Function(_ConsentRequired value)? consentRequired,
    TResult Function(_Conflict value)? conflict,
    TResult Function(_Forbidden value)? forbidden,
    TResult Function(_BusinessRule value)? businessRule,
    TResult Function(_ServiceUnavailable value)? serviceUnavailable,
    required TResult orElse(),
  }) {
    if (consentRequired != null) {
      return consentRequired(this);
    }
    return orElse();
  }
}

abstract class _ConsentRequired implements AppFailure {
  const factory _ConsentRequired({required final String message}) =
      _$ConsentRequiredImpl;

  @override
  String get message;

  /// Create a copy of AppFailure
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ConsentRequiredImplCopyWith<_$ConsentRequiredImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$ConflictImplCopyWith<$Res>
    implements $AppFailureCopyWith<$Res> {
  factory _$$ConflictImplCopyWith(
          _$ConflictImpl value, $Res Function(_$ConflictImpl) then) =
      __$$ConflictImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String message});
}

/// @nodoc
class __$$ConflictImplCopyWithImpl<$Res>
    extends _$AppFailureCopyWithImpl<$Res, _$ConflictImpl>
    implements _$$ConflictImplCopyWith<$Res> {
  __$$ConflictImplCopyWithImpl(
      _$ConflictImpl _value, $Res Function(_$ConflictImpl) _then)
      : super(_value, _then);

  /// Create a copy of AppFailure
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? message = null,
  }) {
    return _then(_$ConflictImpl(
      message: null == message
          ? _value.message
          : message // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc

class _$ConflictImpl implements _Conflict {
  const _$ConflictImpl({required this.message});

  @override
  final String message;

  @override
  String toString() {
    return 'AppFailure.conflict(message: $message)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ConflictImpl &&
            (identical(other.message, message) || other.message == message));
  }

  @override
  int get hashCode => Object.hash(runtimeType, message);

  /// Create a copy of AppFailure
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ConflictImplCopyWith<_$ConflictImpl> get copyWith =>
      __$$ConflictImplCopyWithImpl<_$ConflictImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String message) unexpected,
    required TResult Function(String message) notFound,
    required TResult Function(String message) unauthorized,
    required TResult Function(String message) validation,
    required TResult Function(String message) networkError,
    required TResult Function(String message) consentRequired,
    required TResult Function(String message) conflict,
    required TResult Function(String message) forbidden,
    required TResult Function(String code, String message) businessRule,
    required TResult Function(String message) serviceUnavailable,
  }) {
    return conflict(message);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String message)? unexpected,
    TResult? Function(String message)? notFound,
    TResult? Function(String message)? unauthorized,
    TResult? Function(String message)? validation,
    TResult? Function(String message)? networkError,
    TResult? Function(String message)? consentRequired,
    TResult? Function(String message)? conflict,
    TResult? Function(String message)? forbidden,
    TResult? Function(String code, String message)? businessRule,
    TResult? Function(String message)? serviceUnavailable,
  }) {
    return conflict?.call(message);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String message)? unexpected,
    TResult Function(String message)? notFound,
    TResult Function(String message)? unauthorized,
    TResult Function(String message)? validation,
    TResult Function(String message)? networkError,
    TResult Function(String message)? consentRequired,
    TResult Function(String message)? conflict,
    TResult Function(String message)? forbidden,
    TResult Function(String code, String message)? businessRule,
    TResult Function(String message)? serviceUnavailable,
    required TResult orElse(),
  }) {
    if (conflict != null) {
      return conflict(message);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_Unexpected value) unexpected,
    required TResult Function(_NotFound value) notFound,
    required TResult Function(_Unauthorized value) unauthorized,
    required TResult Function(_Validation value) validation,
    required TResult Function(_NetworkError value) networkError,
    required TResult Function(_ConsentRequired value) consentRequired,
    required TResult Function(_Conflict value) conflict,
    required TResult Function(_Forbidden value) forbidden,
    required TResult Function(_BusinessRule value) businessRule,
    required TResult Function(_ServiceUnavailable value) serviceUnavailable,
  }) {
    return conflict(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_Unexpected value)? unexpected,
    TResult? Function(_NotFound value)? notFound,
    TResult? Function(_Unauthorized value)? unauthorized,
    TResult? Function(_Validation value)? validation,
    TResult? Function(_NetworkError value)? networkError,
    TResult? Function(_ConsentRequired value)? consentRequired,
    TResult? Function(_Conflict value)? conflict,
    TResult? Function(_Forbidden value)? forbidden,
    TResult? Function(_BusinessRule value)? businessRule,
    TResult? Function(_ServiceUnavailable value)? serviceUnavailable,
  }) {
    return conflict?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_Unexpected value)? unexpected,
    TResult Function(_NotFound value)? notFound,
    TResult Function(_Unauthorized value)? unauthorized,
    TResult Function(_Validation value)? validation,
    TResult Function(_NetworkError value)? networkError,
    TResult Function(_ConsentRequired value)? consentRequired,
    TResult Function(_Conflict value)? conflict,
    TResult Function(_Forbidden value)? forbidden,
    TResult Function(_BusinessRule value)? businessRule,
    TResult Function(_ServiceUnavailable value)? serviceUnavailable,
    required TResult orElse(),
  }) {
    if (conflict != null) {
      return conflict(this);
    }
    return orElse();
  }
}

abstract class _Conflict implements AppFailure {
  const factory _Conflict({required final String message}) = _$ConflictImpl;

  @override
  String get message;

  /// Create a copy of AppFailure
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ConflictImplCopyWith<_$ConflictImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$ForbiddenImplCopyWith<$Res>
    implements $AppFailureCopyWith<$Res> {
  factory _$$ForbiddenImplCopyWith(
          _$ForbiddenImpl value, $Res Function(_$ForbiddenImpl) then) =
      __$$ForbiddenImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String message});
}

/// @nodoc
class __$$ForbiddenImplCopyWithImpl<$Res>
    extends _$AppFailureCopyWithImpl<$Res, _$ForbiddenImpl>
    implements _$$ForbiddenImplCopyWith<$Res> {
  __$$ForbiddenImplCopyWithImpl(
      _$ForbiddenImpl _value, $Res Function(_$ForbiddenImpl) _then)
      : super(_value, _then);

  /// Create a copy of AppFailure
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? message = null,
  }) {
    return _then(_$ForbiddenImpl(
      message: null == message
          ? _value.message
          : message // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc

class _$ForbiddenImpl implements _Forbidden {
  const _$ForbiddenImpl({required this.message});

  @override
  final String message;

  @override
  String toString() {
    return 'AppFailure.forbidden(message: $message)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ForbiddenImpl &&
            (identical(other.message, message) || other.message == message));
  }

  @override
  int get hashCode => Object.hash(runtimeType, message);

  /// Create a copy of AppFailure
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ForbiddenImplCopyWith<_$ForbiddenImpl> get copyWith =>
      __$$ForbiddenImplCopyWithImpl<_$ForbiddenImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String message) unexpected,
    required TResult Function(String message) notFound,
    required TResult Function(String message) unauthorized,
    required TResult Function(String message) validation,
    required TResult Function(String message) networkError,
    required TResult Function(String message) consentRequired,
    required TResult Function(String message) conflict,
    required TResult Function(String message) forbidden,
    required TResult Function(String code, String message) businessRule,
    required TResult Function(String message) serviceUnavailable,
  }) {
    return forbidden(message);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String message)? unexpected,
    TResult? Function(String message)? notFound,
    TResult? Function(String message)? unauthorized,
    TResult? Function(String message)? validation,
    TResult? Function(String message)? networkError,
    TResult? Function(String message)? consentRequired,
    TResult? Function(String message)? conflict,
    TResult? Function(String message)? forbidden,
    TResult? Function(String code, String message)? businessRule,
    TResult? Function(String message)? serviceUnavailable,
  }) {
    return forbidden?.call(message);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String message)? unexpected,
    TResult Function(String message)? notFound,
    TResult Function(String message)? unauthorized,
    TResult Function(String message)? validation,
    TResult Function(String message)? networkError,
    TResult Function(String message)? consentRequired,
    TResult Function(String message)? conflict,
    TResult Function(String message)? forbidden,
    TResult Function(String code, String message)? businessRule,
    TResult Function(String message)? serviceUnavailable,
    required TResult orElse(),
  }) {
    if (forbidden != null) {
      return forbidden(message);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_Unexpected value) unexpected,
    required TResult Function(_NotFound value) notFound,
    required TResult Function(_Unauthorized value) unauthorized,
    required TResult Function(_Validation value) validation,
    required TResult Function(_NetworkError value) networkError,
    required TResult Function(_ConsentRequired value) consentRequired,
    required TResult Function(_Conflict value) conflict,
    required TResult Function(_Forbidden value) forbidden,
    required TResult Function(_BusinessRule value) businessRule,
    required TResult Function(_ServiceUnavailable value) serviceUnavailable,
  }) {
    return forbidden(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_Unexpected value)? unexpected,
    TResult? Function(_NotFound value)? notFound,
    TResult? Function(_Unauthorized value)? unauthorized,
    TResult? Function(_Validation value)? validation,
    TResult? Function(_NetworkError value)? networkError,
    TResult? Function(_ConsentRequired value)? consentRequired,
    TResult? Function(_Conflict value)? conflict,
    TResult? Function(_Forbidden value)? forbidden,
    TResult? Function(_BusinessRule value)? businessRule,
    TResult? Function(_ServiceUnavailable value)? serviceUnavailable,
  }) {
    return forbidden?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_Unexpected value)? unexpected,
    TResult Function(_NotFound value)? notFound,
    TResult Function(_Unauthorized value)? unauthorized,
    TResult Function(_Validation value)? validation,
    TResult Function(_NetworkError value)? networkError,
    TResult Function(_ConsentRequired value)? consentRequired,
    TResult Function(_Conflict value)? conflict,
    TResult Function(_Forbidden value)? forbidden,
    TResult Function(_BusinessRule value)? businessRule,
    TResult Function(_ServiceUnavailable value)? serviceUnavailable,
    required TResult orElse(),
  }) {
    if (forbidden != null) {
      return forbidden(this);
    }
    return orElse();
  }
}

abstract class _Forbidden implements AppFailure {
  const factory _Forbidden({required final String message}) = _$ForbiddenImpl;

  @override
  String get message;

  /// Create a copy of AppFailure
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ForbiddenImplCopyWith<_$ForbiddenImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$BusinessRuleImplCopyWith<$Res>
    implements $AppFailureCopyWith<$Res> {
  factory _$$BusinessRuleImplCopyWith(
          _$BusinessRuleImpl value, $Res Function(_$BusinessRuleImpl) then) =
      __$$BusinessRuleImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String code, String message});
}

/// @nodoc
class __$$BusinessRuleImplCopyWithImpl<$Res>
    extends _$AppFailureCopyWithImpl<$Res, _$BusinessRuleImpl>
    implements _$$BusinessRuleImplCopyWith<$Res> {
  __$$BusinessRuleImplCopyWithImpl(
      _$BusinessRuleImpl _value, $Res Function(_$BusinessRuleImpl) _then)
      : super(_value, _then);

  /// Create a copy of AppFailure
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? code = null,
    Object? message = null,
  }) {
    return _then(_$BusinessRuleImpl(
      code: null == code
          ? _value.code
          : code // ignore: cast_nullable_to_non_nullable
              as String,
      message: null == message
          ? _value.message
          : message // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc

class _$BusinessRuleImpl implements _BusinessRule {
  const _$BusinessRuleImpl({required this.code, required this.message});

  @override
  final String code;
  @override
  final String message;

  @override
  String toString() {
    return 'AppFailure.businessRule(code: $code, message: $message)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$BusinessRuleImpl &&
            (identical(other.code, code) || other.code == code) &&
            (identical(other.message, message) || other.message == message));
  }

  @override
  int get hashCode => Object.hash(runtimeType, code, message);

  /// Create a copy of AppFailure
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$BusinessRuleImplCopyWith<_$BusinessRuleImpl> get copyWith =>
      __$$BusinessRuleImplCopyWithImpl<_$BusinessRuleImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String message) unexpected,
    required TResult Function(String message) notFound,
    required TResult Function(String message) unauthorized,
    required TResult Function(String message) validation,
    required TResult Function(String message) networkError,
    required TResult Function(String message) consentRequired,
    required TResult Function(String message) conflict,
    required TResult Function(String message) forbidden,
    required TResult Function(String code, String message) businessRule,
    required TResult Function(String message) serviceUnavailable,
  }) {
    return businessRule(code, message);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String message)? unexpected,
    TResult? Function(String message)? notFound,
    TResult? Function(String message)? unauthorized,
    TResult? Function(String message)? validation,
    TResult? Function(String message)? networkError,
    TResult? Function(String message)? consentRequired,
    TResult? Function(String message)? conflict,
    TResult? Function(String message)? forbidden,
    TResult? Function(String code, String message)? businessRule,
    TResult? Function(String message)? serviceUnavailable,
  }) {
    return businessRule?.call(code, message);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String message)? unexpected,
    TResult Function(String message)? notFound,
    TResult Function(String message)? unauthorized,
    TResult Function(String message)? validation,
    TResult Function(String message)? networkError,
    TResult Function(String message)? consentRequired,
    TResult Function(String message)? conflict,
    TResult Function(String message)? forbidden,
    TResult Function(String code, String message)? businessRule,
    TResult Function(String message)? serviceUnavailable,
    required TResult orElse(),
  }) {
    if (businessRule != null) {
      return businessRule(code, message);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_Unexpected value) unexpected,
    required TResult Function(_NotFound value) notFound,
    required TResult Function(_Unauthorized value) unauthorized,
    required TResult Function(_Validation value) validation,
    required TResult Function(_NetworkError value) networkError,
    required TResult Function(_ConsentRequired value) consentRequired,
    required TResult Function(_Conflict value) conflict,
    required TResult Function(_Forbidden value) forbidden,
    required TResult Function(_BusinessRule value) businessRule,
    required TResult Function(_ServiceUnavailable value) serviceUnavailable,
  }) {
    return businessRule(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_Unexpected value)? unexpected,
    TResult? Function(_NotFound value)? notFound,
    TResult? Function(_Unauthorized value)? unauthorized,
    TResult? Function(_Validation value)? validation,
    TResult? Function(_NetworkError value)? networkError,
    TResult? Function(_ConsentRequired value)? consentRequired,
    TResult? Function(_Conflict value)? conflict,
    TResult? Function(_Forbidden value)? forbidden,
    TResult? Function(_BusinessRule value)? businessRule,
    TResult? Function(_ServiceUnavailable value)? serviceUnavailable,
  }) {
    return businessRule?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_Unexpected value)? unexpected,
    TResult Function(_NotFound value)? notFound,
    TResult Function(_Unauthorized value)? unauthorized,
    TResult Function(_Validation value)? validation,
    TResult Function(_NetworkError value)? networkError,
    TResult Function(_ConsentRequired value)? consentRequired,
    TResult Function(_Conflict value)? conflict,
    TResult Function(_Forbidden value)? forbidden,
    TResult Function(_BusinessRule value)? businessRule,
    TResult Function(_ServiceUnavailable value)? serviceUnavailable,
    required TResult orElse(),
  }) {
    if (businessRule != null) {
      return businessRule(this);
    }
    return orElse();
  }
}

abstract class _BusinessRule implements AppFailure {
  const factory _BusinessRule(
      {required final String code,
      required final String message}) = _$BusinessRuleImpl;

  String get code;
  @override
  String get message;

  /// Create a copy of AppFailure
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$BusinessRuleImplCopyWith<_$BusinessRuleImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$ServiceUnavailableImplCopyWith<$Res>
    implements $AppFailureCopyWith<$Res> {
  factory _$$ServiceUnavailableImplCopyWith(_$ServiceUnavailableImpl value,
          $Res Function(_$ServiceUnavailableImpl) then) =
      __$$ServiceUnavailableImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String message});
}

/// @nodoc
class __$$ServiceUnavailableImplCopyWithImpl<$Res>
    extends _$AppFailureCopyWithImpl<$Res, _$ServiceUnavailableImpl>
    implements _$$ServiceUnavailableImplCopyWith<$Res> {
  __$$ServiceUnavailableImplCopyWithImpl(_$ServiceUnavailableImpl _value,
      $Res Function(_$ServiceUnavailableImpl) _then)
      : super(_value, _then);

  /// Create a copy of AppFailure
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? message = null,
  }) {
    return _then(_$ServiceUnavailableImpl(
      message: null == message
          ? _value.message
          : message // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc

class _$ServiceUnavailableImpl implements _ServiceUnavailable {
  const _$ServiceUnavailableImpl({required this.message});

  @override
  final String message;

  @override
  String toString() {
    return 'AppFailure.serviceUnavailable(message: $message)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ServiceUnavailableImpl &&
            (identical(other.message, message) || other.message == message));
  }

  @override
  int get hashCode => Object.hash(runtimeType, message);

  /// Create a copy of AppFailure
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ServiceUnavailableImplCopyWith<_$ServiceUnavailableImpl> get copyWith =>
      __$$ServiceUnavailableImplCopyWithImpl<_$ServiceUnavailableImpl>(
          this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String message) unexpected,
    required TResult Function(String message) notFound,
    required TResult Function(String message) unauthorized,
    required TResult Function(String message) validation,
    required TResult Function(String message) networkError,
    required TResult Function(String message) consentRequired,
    required TResult Function(String message) conflict,
    required TResult Function(String message) forbidden,
    required TResult Function(String code, String message) businessRule,
    required TResult Function(String message) serviceUnavailable,
  }) {
    return serviceUnavailable(message);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(String message)? unexpected,
    TResult? Function(String message)? notFound,
    TResult? Function(String message)? unauthorized,
    TResult? Function(String message)? validation,
    TResult? Function(String message)? networkError,
    TResult? Function(String message)? consentRequired,
    TResult? Function(String message)? conflict,
    TResult? Function(String message)? forbidden,
    TResult? Function(String code, String message)? businessRule,
    TResult? Function(String message)? serviceUnavailable,
  }) {
    return serviceUnavailable?.call(message);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String message)? unexpected,
    TResult Function(String message)? notFound,
    TResult Function(String message)? unauthorized,
    TResult Function(String message)? validation,
    TResult Function(String message)? networkError,
    TResult Function(String message)? consentRequired,
    TResult Function(String message)? conflict,
    TResult Function(String message)? forbidden,
    TResult Function(String code, String message)? businessRule,
    TResult Function(String message)? serviceUnavailable,
    required TResult orElse(),
  }) {
    if (serviceUnavailable != null) {
      return serviceUnavailable(message);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_Unexpected value) unexpected,
    required TResult Function(_NotFound value) notFound,
    required TResult Function(_Unauthorized value) unauthorized,
    required TResult Function(_Validation value) validation,
    required TResult Function(_NetworkError value) networkError,
    required TResult Function(_ConsentRequired value) consentRequired,
    required TResult Function(_Conflict value) conflict,
    required TResult Function(_Forbidden value) forbidden,
    required TResult Function(_BusinessRule value) businessRule,
    required TResult Function(_ServiceUnavailable value) serviceUnavailable,
  }) {
    return serviceUnavailable(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_Unexpected value)? unexpected,
    TResult? Function(_NotFound value)? notFound,
    TResult? Function(_Unauthorized value)? unauthorized,
    TResult? Function(_Validation value)? validation,
    TResult? Function(_NetworkError value)? networkError,
    TResult? Function(_ConsentRequired value)? consentRequired,
    TResult? Function(_Conflict value)? conflict,
    TResult? Function(_Forbidden value)? forbidden,
    TResult? Function(_BusinessRule value)? businessRule,
    TResult? Function(_ServiceUnavailable value)? serviceUnavailable,
  }) {
    return serviceUnavailable?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_Unexpected value)? unexpected,
    TResult Function(_NotFound value)? notFound,
    TResult Function(_Unauthorized value)? unauthorized,
    TResult Function(_Validation value)? validation,
    TResult Function(_NetworkError value)? networkError,
    TResult Function(_ConsentRequired value)? consentRequired,
    TResult Function(_Conflict value)? conflict,
    TResult Function(_Forbidden value)? forbidden,
    TResult Function(_BusinessRule value)? businessRule,
    TResult Function(_ServiceUnavailable value)? serviceUnavailable,
    required TResult orElse(),
  }) {
    if (serviceUnavailable != null) {
      return serviceUnavailable(this);
    }
    return orElse();
  }
}

abstract class _ServiceUnavailable implements AppFailure {
  const factory _ServiceUnavailable({required final String message}) =
      _$ServiceUnavailableImpl;

  @override
  String get message;

  /// Create a copy of AppFailure
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ServiceUnavailableImplCopyWith<_$ServiceUnavailableImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
