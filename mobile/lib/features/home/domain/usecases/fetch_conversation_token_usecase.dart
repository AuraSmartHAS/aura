import 'package:aura/core/errors/result.dart';
import '../repositories/conversation_repository.dart';

class FetchConversationTokenUseCase {
  final ConversationRepository _repository;

  FetchConversationTokenUseCase(this._repository);

  Future<Result<String>> call() => _repository.fetchToken();
}
