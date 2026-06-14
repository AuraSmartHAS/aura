import 'package:aura/core/errors/result.dart';
import '../entities/conversation_entity.dart';
import '../entities/transcript_message_entity.dart';

abstract class ConversationRepository {
  Stream<ConversationStatus> get statusStream;
  Stream<ConversationMode> get modeStream;
  Stream<bool> get isMutedStream;
  Stream<List<TranscriptMessageEntity>> get transcriptStream;

  Future<Result<String>> fetchToken();
  Future<Result<void>> startConversation(String token);
  Future<Result<void>> stopConversation();
  Future<Result<void>> setMicMuted(bool muted);
}
