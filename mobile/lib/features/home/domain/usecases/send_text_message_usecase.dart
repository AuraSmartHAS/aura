import 'package:aura/core/errors/result.dart';
import '../repositories/conversation_repository.dart';

/// Caminho não-vocal (correção C4): entrega o texto escrito à mesma sessão de
/// conversa que a voz usa.
class SendTextMessageUseCase {
  final ConversationRepository _repository;

  SendTextMessageUseCase(this._repository);

  Future<Result<void>> call(String text) => _repository.sendTextMessage(text);
}
