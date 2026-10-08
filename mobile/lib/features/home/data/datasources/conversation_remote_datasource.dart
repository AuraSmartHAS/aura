import 'package:aura/core/errors/result.dart';
import 'package:aura/core/network/api_client.dart';

abstract class ConversationRemoteDataSource {
  Future<Result<String>> fetchToken();
}

/// Token da conversa por voz, emitido pelo backend (`GET /voice/token`).
///
/// Antes vinha de uma Edge Function aberta do Supabase. Agora a chave do
/// ElevenLabs fica só no servidor e a rota exige o JWT que o [ApiClient] já
/// injeta.
class ConversationRemoteDataSourceImpl implements ConversationRemoteDataSource {
  final ApiClient _apiClient;

  ConversationRemoteDataSourceImpl(this._apiClient);

  @override
  Future<Result<String>> fetchToken() async {
    try {
      final response = await _apiClient.dio.get('/voice/token');

      final data = response.data as Map<String, dynamic>;
      final token = data['token'] as String? ?? '';
      if (token.isEmpty) {
        return Failure(Exception('Empty token received'));
      }

      return Success(token);
    } catch (e) {
      return Failure(Exception('Failed to fetch token: ${e.toString()}'));
    }
  }
}
