import 'package:aura/core/errors/result.dart';
import '../repositories/conversation_repository.dart';

class ToggleMuteUseCase {
  final ConversationRepository _repository;

  ToggleMuteUseCase(this._repository);

  Future<Result<void>> call(bool muted) => _repository.setMicMuted(muted);
}
