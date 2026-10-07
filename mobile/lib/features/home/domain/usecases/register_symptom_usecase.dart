import 'package:aura/core/errors/result.dart';
import '../repositories/symptom_repository.dart';

/// Registra um relato da Maria feito por voz. Só observação: nada é
/// diagnosticado nem prescrito.
class RegisterSymptomUseCase {
  RegisterSymptomUseCase(this._repository);

  final SymptomRepository _repository;

  Future<Result<String>> call({
    required String homeId,
    required String type,
    required Map<String, dynamic> value,
  }) =>
      _repository.register(homeId: homeId, type: type, value: value);
}
