import 'package:freezed_annotation/freezed_annotation.dart';
import '../../domain/entities/transcript_message_entity.dart';

part 'transcript_message_model.freezed.dart';
part 'transcript_message_model.g.dart';

@freezed
class TranscriptMessageModel with _$TranscriptMessageModel {
  const factory TranscriptMessageModel({
    required String text,
    required bool isUser,
  }) = _TranscriptMessageModel;

  factory TranscriptMessageModel.fromJson(Map<String, dynamic> json) =>
      _$TranscriptMessageModelFromJson(json);
}

extension TranscriptMessageModelX on TranscriptMessageModel {
  TranscriptMessageEntity toEntity() => TranscriptMessageEntity(
    text: text,
    isUser: isUser,
  );
}

extension TranscriptMessageEntityX on TranscriptMessageEntity {
  TranscriptMessageModel toModel() => TranscriptMessageModel(
    text: text,
    isUser: isUser,
  );
}
