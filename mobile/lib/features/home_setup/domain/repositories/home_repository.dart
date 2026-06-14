import 'package:aura/core/errors/result.dart';
import '../entities/home.dart';

abstract class HomeRepository {
  /// Creates a home (resolves address via ViaCEP) and persists it as the active
  /// home for the session.
  Future<Result<Home>> createHome({
    required String patientName,
    String? birthDate,
    required String cep,
    String? label,
  });

  Future<Result<HomeDetail>> getHome(String homeId);

  Future<Result<Map<String, bool>>> updateChecklist(
    String homeId,
    Map<String, bool> items,
  );
}
