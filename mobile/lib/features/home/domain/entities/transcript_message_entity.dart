import 'package:freezed_annotation/freezed_annotation.dart';

part 'transcript_message_entity.freezed.dart';

@freezed
class TranscriptMessageEntity with _$TranscriptMessageEntity {
  const factory TranscriptMessageEntity({
    required String text,
    required bool isUser,
  }) = _TranscriptMessageEntity;
}
