import 'package:freezed_annotation/freezed_annotation.dart';
import '../../../auth/domain/entities/user_entity.dart';

part 'user_model.freezed.dart';
part 'user_model.g.dart';

@freezed
class UserModel with _$UserModel {
  const factory UserModel({
    required String id,
    required String email,
    required String? fullName,
  }) = _UserModel;

  factory UserModel.fromJson(Map<String, dynamic> json) =>
      _$UserModelFromJson(json);
}

extension UserModelX on UserModel {
  UserEntity toEntity() => UserEntity(
    id: id,
    email: email,
    fullName: fullName,
  );
}

extension UserEntityX on UserEntity {
  UserModel toModel() => UserModel(
    id: id,
    email: email,
    fullName: fullName,
  );
}
