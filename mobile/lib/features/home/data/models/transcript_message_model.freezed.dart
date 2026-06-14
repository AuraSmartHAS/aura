// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'transcript_message_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

TranscriptMessageModel _$TranscriptMessageModelFromJson(
    Map<String, dynamic> json) {
  return _TranscriptMessageModel.fromJson(json);
}

/// @nodoc
mixin _$TranscriptMessageModel {
  String get text => throw _privateConstructorUsedError;
  bool get isUser => throw _privateConstructorUsedError;

  /// Serializes this TranscriptMessageModel to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of TranscriptMessageModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $TranscriptMessageModelCopyWith<TranscriptMessageModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TranscriptMessageModelCopyWith<$Res> {
  factory $TranscriptMessageModelCopyWith(TranscriptMessageModel value,
          $Res Function(TranscriptMessageModel) then) =
      _$TranscriptMessageModelCopyWithImpl<$Res, TranscriptMessageModel>;
  @useResult
  $Res call({String text, bool isUser});
}

/// @nodoc
class _$TranscriptMessageModelCopyWithImpl<$Res,
        $Val extends TranscriptMessageModel>
    implements $TranscriptMessageModelCopyWith<$Res> {
  _$TranscriptMessageModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of TranscriptMessageModel
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
abstract class _$$TranscriptMessageModelImplCopyWith<$Res>
    implements $TranscriptMessageModelCopyWith<$Res> {
  factory _$$TranscriptMessageModelImplCopyWith(
          _$TranscriptMessageModelImpl value,
          $Res Function(_$TranscriptMessageModelImpl) then) =
      __$$TranscriptMessageModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String text, bool isUser});
}

/// @nodoc
class __$$TranscriptMessageModelImplCopyWithImpl<$Res>
    extends _$TranscriptMessageModelCopyWithImpl<$Res,
        _$TranscriptMessageModelImpl>
    implements _$$TranscriptMessageModelImplCopyWith<$Res> {
  __$$TranscriptMessageModelImplCopyWithImpl(
      _$TranscriptMessageModelImpl _value,
      $Res Function(_$TranscriptMessageModelImpl) _then)
      : super(_value, _then);

  /// Create a copy of TranscriptMessageModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? text = null,
    Object? isUser = null,
  }) {
    return _then(_$TranscriptMessageModelImpl(
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
@JsonSerializable()
class _$TranscriptMessageModelImpl implements _TranscriptMessageModel {
  const _$TranscriptMessageModelImpl(
      {required this.text, required this.isUser});

  factory _$TranscriptMessageModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$TranscriptMessageModelImplFromJson(json);

  @override
  final String text;
  @override
  final bool isUser;

  @override
  String toString() {
    return 'TranscriptMessageModel(text: $text, isUser: $isUser)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TranscriptMessageModelImpl &&
            (identical(other.text, text) || other.text == text) &&
            (identical(other.isUser, isUser) || other.isUser == isUser));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, text, isUser);

  /// Create a copy of TranscriptMessageModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TranscriptMessageModelImplCopyWith<_$TranscriptMessageModelImpl>
      get copyWith => __$$TranscriptMessageModelImplCopyWithImpl<
          _$TranscriptMessageModelImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$TranscriptMessageModelImplToJson(
      this,
    );
  }
}

abstract class _TranscriptMessageModel implements TranscriptMessageModel {
  const factory _TranscriptMessageModel(
      {required final String text,
      required final bool isUser}) = _$TranscriptMessageModelImpl;

  factory _TranscriptMessageModel.fromJson(Map<String, dynamic> json) =
      _$TranscriptMessageModelImpl.fromJson;

  @override
  String get text;
  @override
  bool get isUser;

  /// Create a copy of TranscriptMessageModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TranscriptMessageModelImplCopyWith<_$TranscriptMessageModelImpl>
      get copyWith => throw _privateConstructorUsedError;
}
