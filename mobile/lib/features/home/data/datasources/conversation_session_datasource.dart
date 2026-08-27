import 'dart:async';

import 'package:aura/core/errors/app_failure.dart';
import 'package:aura/core/errors/result.dart';
import 'package:elevenlabs_agents/elevenlabs_agents.dart' as sdk;

import '../../domain/entities/conversation_entity.dart';
import '../../domain/entities/transcript_message_entity.dart';

/// Builds the SDK client around the callbacks assembled by the datasource.
/// Exists so tests can substitute the client without a live LiveKit room.
typedef ConversationClientFactory = sdk.ConversationClient Function(
  sdk.ConversationCallbacks callbacks,
);

abstract class ConversationSessionDataSource {
  Stream<ConversationStatus> get statusStream;
  Stream<ConversationMode> get modeStream;
  Stream<bool> get isMutedStream;
  Stream<List<TranscriptMessageEntity>> get transcriptStream;

  /// Raw SDK error messages. The session client reports send failures through
  /// its `onError` callback instead of throwing, so this is the only channel
  /// where a failed text message shows up.
  Stream<String> get errorStream;

  Future<Result<void>> start(String token);
  Future<Result<void>> stop();
  Future<Result<void>> setMicMuted(bool muted);

  /// Non-vocal path (correção C4): sends typed text to the live session.
  Future<Result<void>> sendText(String text);
}

class ConversationSessionDataSourceImpl implements ConversationSessionDataSource {
  late final sdk.ConversationClient _client;

  final _statusController = StreamController<ConversationStatus>.broadcast();
  final _modeController = StreamController<ConversationMode>.broadcast();
  final _isMutedController = StreamController<bool>.broadcast();
  final _transcriptController = StreamController<List<TranscriptMessageEntity>>.broadcast();
  final _errorController = StreamController<String>.broadcast();

  List<TranscriptMessageEntity> _transcript = [];

  ConversationSessionDataSourceImpl({ConversationClientFactory? clientFactory}) {
    final callbacks = sdk.ConversationCallbacks(
      onError: (String message, [dynamic context]) {
        _statusController.add(ConversationStatus.error);
        _errorController.add(message);
      },
      onStatusChange: ({required sdk.ConversationStatus status}) {
        _statusController.add(_mapStatus(status));
      },
      onModeChange: ({required sdk.ConversationMode mode}) {
        _modeController.add(_mapMode(mode));
      },
      onUserTranscript: ({required String transcript, required int eventId}) {
        _appendMessage(TranscriptMessageEntity(text: transcript, isUser: true));
      },
      onMessage: ({required String message, required sdk.Role source}) {
        if (source == sdk.Role.ai) {
          _appendMessage(TranscriptMessageEntity(text: message, isUser: false));
        }
      },
    );

    _client = clientFactory?.call(callbacks) ??
        sdk.ConversationClient(callbacks: callbacks);
  }

  void _appendMessage(TranscriptMessageEntity message) {
    _transcript = [..._transcript, message];
    _transcriptController.add(_transcript);
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
  Stream<String> get errorStream => _errorController.stream;

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

  @override
  Future<Result<void>> sendText(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return const Failure(AppFailure.validation(message: 'Mensagem vazia.'));
    }

    try {
      // `sendUserMessage` devolve void: só a sessão fechada estoura aqui
      // (StateError). Falha depois de conectado volta pelo `onError`, e é por
      // isso que existe o `errorStream`.
      _client.sendUserMessage(trimmed);
    } catch (e) {
      return Failure(AppFailure.unexpected(message: e.toString()));
    }

    // O texto entra no transcript pelo mesmo lugar que a fala: o transcript
    // continua com uma fonte de verdade só.
    _appendMessage(TranscriptMessageEntity(text: trimmed, isUser: true));
    return const Success(null);
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
    _errorController.close();
  }
}
