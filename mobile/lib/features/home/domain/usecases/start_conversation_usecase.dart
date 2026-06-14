import 'package:aura/core/errors/result.dart';
import '../repositories/conversation_repository.dart';

class StartConversationUseCase {
  final ConversationRepository _repository;

  StartConversationUseCase(this._repository);

  Future<Result<void>> call(String token) => _repository.startConversation(token);
}
