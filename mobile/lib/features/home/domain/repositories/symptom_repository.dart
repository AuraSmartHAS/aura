import 'package:aura/core/errors/result.dart';

/// Relato falado de um sintoma, enviado como sinal (`POST /signals`).
abstract class SymptomRepository {
  /// Devolve o id do sinal gravado pelo servidor.
  Future<Result<String>> register({
    required String homeId,
    required String type,
    required Map<String, dynamic> value,
  });
}
