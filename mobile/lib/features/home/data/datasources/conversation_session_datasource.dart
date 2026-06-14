import 'dart:async';

import 'package:aura/core/errors/app_failure.dart';
import 'package:aura/core/errors/result.dart';
import 'package:elevenlabs_agents/elevenlabs_agents.dart' as sdk;

import '../../domain/entities/conversation_entity.dart';
import '../../domain/entities/transcript_message_entity.dart';

abstract class ConversationSessionDataSource {
  Stream<ConversationStatus> get statusStream;
  Stream<ConversationMode> get modeStream;
  Stream<bool> get isMutedStream;
  Stream<List<TranscriptMessageEntity>> get transcriptStream;

  Future<Result<void>> start(String token);
  Future<Result<void>> stop();
  Future<Result<void>> setMicMuted(bool muted);
}

class ConversationSessionDataSourceImpl implements ConversationSessionDataSource {
  late final sdk.ConversationClient _client;

  final _statusController = StreamController<ConversationStatus>.broadcast();
  final _modeController = StreamController<ConversationMode>.broadcast();
  final _isMutedController = StreamController<bool>.broadcast();
  final _transcriptController = StreamController<List<TranscriptMessageEntity>>.broadcast();

  List<TranscriptMessageEntity> _transcript = [];

  ConversationSessionDataSourceImpl() {
    _client = sdk.ConversationClient(
      callbacks: sdk.ConversationCallbacks(
        onError: (String message, [dynamic context]) {
          _statusController.add(ConversationStatus.error);
        },
        onStatusChange: ({required sdk.ConversationStatus status}) {
          _statusController.add(_mapStatus(status));
        },
        onModeChange: ({required sdk.ConversationMode mode}) {
          _modeController.add(_mapMode(mode));
        },
        onUserTranscript: ({required String transcript, required int eventId}) {
          _transcript = [
            ..._transcript,
            TranscriptMessageEntity(text: transcript, isUser: true),
          ];
          _transcriptController.add(_transcript);
        },
        onMessage: ({required String message, required sdk.Role source}) {
          if (source == sdk.Role.ai) {
            _transcript = [
              ..._transcript,
              TranscriptMessageEntity(text: message, isUser: false),
            ];
            _transcriptController.add(_transcript);
          }
        },
      ),
    );
  }

  @override
  Stream<ConversationStatus> get statusStream => _statusController.stream;

  @override
  Stream<ConversationMode> get modeStream => _modeController.stream;

  @override
  Stream<bool> get isMutedStream => _isMutedController.stream;

  @override
  Stream<List<TranscriptMessageEntity>> get transcriptStream =>
      _transcriptController.stream;

  @override
  Future<Result<void>> start(String token) async {
    try {
      _transcript = [];
      _transcriptController.add(_transcript);
      await _client.startSession(conversationToken: token);
      _isMutedController.add(false);
      return const Success(null);
    } catch (e) {
      return Failure(AppFailure.unexpected(message: e.toString()));
    }
  }

  @override
  Future<Result<void>> stop() async {
    try {
      await _client.endSession();
      return const Success(null);
    } catch (e) {
      return Failure(AppFailure.unexpected(message: e.toString()));
    }
  }

  @override
  Future<Result<void>> setMicMuted(bool muted) async {
    try {
      await _client.setMicMuted(muted);
      _isMutedController.add(muted);
      return const Success(null);
    } catch (e) {
      return Failure(AppFailure.unexpected(message: e.toString()));
    }
  }

  ConversationStatus _mapStatus(sdk.ConversationStatus status) {
    return switch (status) {
      sdk.ConversationStatus.disconnected => ConversationStatus.disconnected,
      sdk.ConversationStatus.connecting => ConversationStatus.connecting,
      sdk.ConversationStatus.connected => ConversationStatus.connected,
      sdk.ConversationStatus.disconnecting => ConversationStatus.disconnecting,
    };
  }

  ConversationMode _mapMode(sdk.ConversationMode mode) {
    return switch (mode) {
      sdk.ConversationMode.listening => ConversationMode.listening,
      sdk.ConversationMode.speaking => ConversationMode.speaking,
    };
  }

  void dispose() {
    _client.dispose();
    _statusController.close();
    _modeController.close();
    _isMutedController.close();
    _transcriptController.close();
  }
}
