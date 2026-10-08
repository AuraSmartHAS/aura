import 'package:aura/core/network/api_client.dart';

abstract class SymptomRemoteDataSource {
  /// `POST /signals` com `source=voice`. Devolve o `signalId` do servidor.
  Future<String> postVoiceSignal({
    required String homeId,
    required String type,
    required Map<String, dynamic> value,
  });
}

class SymptomRemoteDataSourceImpl implements SymptomRemoteDataSource {
  SymptomRemoteDataSourceImpl(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<String> postVoiceSignal({
    required String homeId,
    required String type,
    required Map<String, dynamic> value,
  }) async {
    final response = await _apiClient.dio.post('/signals', data: {
      'homeId': homeId,
      'type': type,
      'source': 'voice',
      'value': value,
    });
    final data = response.data;
    final id = data is Map ? data['signalId'] : null;
    if (id is! String || id.isEmpty) {
      // Sem o id não há recibo do servidor, e sem recibo não há "registrado".
      throw const FormatException('Resposta sem signalId');
    }
    return id;
  }
}
