// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'transcript_message_entity.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$TranscriptMessageEntity {
  String get text => throw _privateConstructorUsedError;
  bool get isUser => throw _privateConstructorUsedError;

  /// Create a copy of TranscriptMessageEntity
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $TranscriptMessageEntityCopyWith<TranscriptMessageEntity> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TranscriptMessageEntityCopyWith<$Res> {
  factory $TranscriptMessageEntityCopyWith(TranscriptMessageEntity value,
          $Res Function(TranscriptMessageEntity) then) =
      _$TranscriptMessageEntityCopyWithImpl<$Res, TranscriptMessageEntity>;
  @useResult
  $Res call({String text, bool isUser});
}

/// @nodoc
class _$TranscriptMessageEntityCopyWithImpl<$Res,
        $Val extends TranscriptMessageEntity>
    implements $TranscriptMessageEntityCopyWith<$Res> {
  _$TranscriptMessageEntityCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of TranscriptMessageEntity
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? text = null,
    Object? isUser = null,
  }) {
    return _then(_value.copyWith(
      text: null == text
          ? _value.text
          : text // ignore: cast_nullable_to_non_nullable
              as String,
      isUser: null == isUser
          ? _value.isUser
          : isUser // ignore: cast_nullable_to_non_nullable
              as bool,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$TranscriptMessageEntityImplCopyWith<$Res>
    implements $TranscriptMessageEntityCopyWith<$Res> {
  factory _$$TranscriptMessageEntityImplCopyWith(
          _$TranscriptMessageEntityImpl value,
          $Res Function(_$TranscriptMessageEntityImpl) then) =
      __$$TranscriptMessageEntityImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String text, bool isUser});
}

/// @nodoc
class __$$TranscriptMessageEntityImplCopyWithImpl<$Res>
    extends _$TranscriptMessageEntityCopyWithImpl<$Res,
        _$TranscriptMessageEntityImpl>
    implements _$$TranscriptMessageEntityImplCopyWith<$Res> {
  __$$TranscriptMessageEntityImplCopyWithImpl(
      _$TranscriptMessageEntityImpl _value,
      $Res Function(_$TranscriptMessageEntityImpl) _then)
      : super(_value, _then);

  /// Create a copy of TranscriptMessageEntity
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? text = null,
    Object? isUser = null,
  }) {
    return _then(_$TranscriptMessageEntityImpl(
      text: null == text
          ? _value.text
          : text // ignore: cast_nullable_to_non_nullable
              as String,
      isUser: null == isUser
          ? _value.isUser
          : isUser // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc

class _$TranscriptMessageEntityImpl implements _TranscriptMessageEntity {
  const _$TranscriptMessageEntityImpl(
      {required this.text, required this.isUser});

  @override
  final String text;
  @override
  final bool isUser;

  @override
  String toString() {
    return 'TranscriptMessageEntity(text: $text, isUser: $isUser)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TranscriptMessageEntityImpl &&
            (identical(other.text, text) || other.text == text) &&
            (identical(other.isUser, isUser) || other.isUser == isUser));
  }

  @override
  int get hashCode => Object.hash(runtimeType, text, isUser);

  /// Create a copy of TranscriptMessageEntity
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TranscriptMessageEntityImplCopyWith<_$TranscriptMessageEntityImpl>
      get copyWith => __$$TranscriptMessageEntityImplCopyWithImpl<
          _$TranscriptMessageEntityImpl>(this, _$identity);
}

abstract class _TranscriptMessageEntity implements TranscriptMessageEntity {
  const factory _TranscriptMessageEntity(
      {required final String text,
      required final bool isUser}) = _$TranscriptMessageEntityImpl;

  @override
  String get text;
  @override
  bool get isUser;

  /// Create a copy of TranscriptMessageEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TranscriptMessageEntityImplCopyWith<_$TranscriptMessageEntityImpl>
      get copyWith => throw _privateConstructorUsedError;
}
