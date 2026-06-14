import 'package:aura/core/errors/result.dart';
import '../entities/home.dart';
import '../repositories/home_repository.dart';

class GetHomeUseCase {
  GetHomeUseCase(this._repository);

  final HomeRepository _repository;

  Future<Result<HomeDetail>> call(String homeId) => _repository.getHome(homeId);
}
