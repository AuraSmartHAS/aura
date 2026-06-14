import 'package:aura/core/errors/result.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract class ConversationRemoteDataSource {
  Future<Result<String>> fetchToken();
}

class ConversationRemoteDataSourceImpl implements ConversationRemoteDataSource {
  final SupabaseClient _supabaseClient;

  ConversationRemoteDataSourceImpl(this._supabaseClient);

  @override
  Future<Result<String>> fetchToken() async {
    try {
      final response = await _supabaseClient.functions.invoke(
        'elevenlabs-token',
      );

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
