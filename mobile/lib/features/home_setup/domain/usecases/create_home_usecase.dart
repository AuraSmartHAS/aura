import 'package:aura/core/errors/result.dart';
import '../entities/home.dart';
import '../repositories/home_repository.dart';

class CreateHomeUseCase {
  CreateHomeUseCase(this._repository);

  final HomeRepository _repository;

  Future<Result<Home>> call({
    required String patientName,
    String? birthDate,
    required String cep,
    String? label,
  }) =>
      _repository.createHome(
        patientName: patientName,
        birthDate: birthDate,
        cep: cep,
        label: label,
      );
}
