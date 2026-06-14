import 'package:aura/core/errors/app_failure.dart';
import 'package:aura/core/errors/result.dart';
import 'package:flutter/cupertino.dart';
import '../../domain/entities/conversation_entity.dart';
import '../../domain/entities/transcript_message_entity.dart';
import '../../domain/repositories/conversation_repository.dart';
import '../datasources/conversation_remote_datasource.dart';
import '../datasources/conversation_session_datasource.dart';

class ConversationRepositoryImpl implements ConversationRepository {
  final ConversationRemoteDataSource _remoteDataSource;
  final ConversationSessionDataSource _sessionDataSource;

  ConversationRepositoryImpl(
    this._remoteDataSource,
    this._sessionDataSource,
  );

  @override
  Stream<ConversationStatus> get statusStream => _sessionDataSource.statusStream;

  @override
  Stream<ConversationMode> get modeStream => _sessionDataSource.modeStream;

  @override
  Stream<bool> get isMutedStream => _sessionDataSource.isMutedStream;

  @override
  Stream<List<TranscriptMessageEntity>> get transcriptStream =>
      _sessionDataSource.transcriptStream;

  @override
  Future<Result<String>> fetchToken() async {
    try {
      final result = await _remoteDataSource.fetchToken();
      return result;
    } catch (e) {
      debugPrint("[ASDFGHJKL] fetch token - $e");
      return Failure(
        AppFailure.unexpected(message: e.toString()),
      );
    }
  }

  @override
  Future<Result<void>> startConversation(String token) async {
    try {
      final result = await _sessionDataSource.start(token);
      return result;
    } catch (e) {
      debugPrint("[ASDFGHJKL] start conversation - $e");
      return Failure(
        AppFailure.unexpected(message: e.toString()),
      );
    }
  }

  @override
  Future<Result<void>> stopConversation() async {
    try {
      final result = await _sessionDataSource.stop();
      return result;
    } catch (e) {
      debugPrint("[ASDFGHJKL] stop conversation - $e");
      return Failure(
        AppFailure.unexpected(message: e.toString()),
      );
    }
  }

  @override
  Future<Result<void>> setMicMuted(bool muted) async {
    try {
      final result = await _sessionDataSource.setMicMuted(muted);
      return result;
    } catch (e) {
      debugPrint("[ASDFGHJKL] set mic muted - $e");
      return Failure(
        AppFailure.unexpected(message: e.toString()),
      );
    }
  }
}
