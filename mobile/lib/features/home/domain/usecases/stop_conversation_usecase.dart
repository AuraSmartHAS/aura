import 'package:aura/core/errors/result.dart';
import '../repositories/conversation_repository.dart';

class StopConversationUseCase {
  final ConversationRepository _repository;

  StopConversationUseCase(this._repository);

  Future<Result<void>> call() => _repository.stopConversation();
}
