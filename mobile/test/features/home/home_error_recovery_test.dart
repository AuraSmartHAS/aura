import 'dart:async';
import 'dart:io';

import 'package:aura/core/errors/app_failure.dart';
import 'package:aura/core/errors/result.dart';
import 'package:aura/features/home/domain/entities/conversation_entity.dart';
import 'package:aura/features/home/domain/entities/transcript_message_entity.dart';
import 'package:aura/features/home/domain/repositories/conversation_repository.dart';
import 'package:aura/features/home/domain/usecases/fetch_conversation_token_usecase.dart';
import 'package:aura/features/home/domain/usecases/send_text_message_usecase.dart';
import 'package:aura/features/home/domain/usecases/start_conversation_usecase.dart';
import 'package:aura/features/home/domain/usecases/stop_conversation_usecase.dart';
import 'package:aura/features/home/domain/usecases/toggle_mute_usecase.dart';
import 'package:aura/features/home/presentation/bloc/home_bloc.dart';
import 'package:aura/features/home/presentation/home_error_copy.dart';
import 'package:flutter_test/flutter_test.dart';

/// Correção C6 — erros humanos e recuperação.
///
/// Dois achados da auditoria de UX:
/// - AL-1: a tela da Maria mostrava inglês com jargão ("Token not available").
/// - AL-2: o erro nunca ia embora — o banner vermelho ficava para sempre, e
///   para uma pessoa de 74 anos isso lê como "o aparelho quebrou".
void main() {
  test(
      'AL-2 — modo avião no meio da sessão: a Maria lê português e, ao voltar '
      'a internet, o aviso some sozinho', () async {
    final repository = _FakeConversationRepository();
    addTearDown(repository.dispose);
    final bloc = _buildBloc(repository);
    addTearDown(bloc.close);

    bloc.add(const HomeInitEvent());
    await _tick();
    bloc.add(const HomeMicTappedEvent());
    await _tick();
    expect(bloc.state.voiceState, VoiceUIState.listening);

    // Modo avião: a sessão cai e o SDK avisa em inglês, pelo `onError`.
    repository.emitDrop('ClientException: Failed host lookup: api.elevenlabs.io');
    await _tick();

    expect(bloc.state.errorMessage, HomeErrorCopy.of(HomeErrorCode.network));
    expect(bloc.state.errorMessage, contains('Sem internet'));
    expect(bloc.state.voiceState, VoiceUIState.error);

    // A internet volta. Ninguém tocou em nada.
    repository.emitReconnected();
    await _tick();

    expect(bloc.state.errorMessage, isNull);
    expect(bloc.state.notice, HomeErrorCopy.recovered);
    expect(bloc.state.voiceState, VoiceUIState.listening);
  });

  test('a resposta nova da Aura também dispensa o erro velho', () async {
    final repository = _FakeConversationRepository();
    addTearDown(repository.dispose);
    final bloc = _buildBloc(repository);
    addTearDown(bloc.close);

    bloc.add(const HomeInitEvent());
    await _tick();
    repository.emitDrop('Failed to send message');
    await _tick();
    expect(bloc.state.errorMessage, isNotNull);

    repository.emitAuraMessage('Já estou aqui de novo. Como você está?');
    await _tick();

    expect(bloc.state.errorMessage, isNull);
  });

  group('dicionário de erros', () {
    // Mensagens cruas que o app produz hoje — as do SDK de voz e as das
    // camadas de dados — e o código que cada uma tem de virar.
    const casos = <String, HomeErrorCode>{
      'Token not available for this conversation':
          HomeErrorCode.tokenUnavailable,
      'Exception: Failed to fetch token: 500': HomeErrorCode.tokenUnavailable,
      'Failed to start conversation': HomeErrorCode.startFailed,
      'Failed to send message': HomeErrorCode.sendFailed,
      'Failed to send user message: not connected': HomeErrorCode.sendFailed,
      'Microphone permission denied by the user': HomeErrorCode.microphone,
      'Session closed unexpectedly': HomeErrorCode.connectionLost,
      'WebSocket connection closed: 1006': HomeErrorCode.connectionLost,
      'SocketException: Network is unreachable': HomeErrorCode.network,
      'Connection timed out': HomeErrorCode.network,
      'Something completely unheard of': HomeErrorCode.unknown,
      '': HomeErrorCode.unknown,
    };

    casos.forEach((raw, esperado) {
      test('"$raw" vira ${esperado.name}', () {
        expect(HomeErrorCopy.codeFor(raw), esperado);
        expect(HomeErrorCopy.fromRaw(raw), HomeErrorCopy.of(esperado));
      });
    });

    test('cada código tem uma frase própria, com o que houve e o que fazer',
        () {
      final frases = HomeErrorCopy.all;
      expect(frases, hasLength(HomeErrorCode.values.length));
      expect(frases.toSet(), hasLength(frases.length));
      for (final frase in frases) {
        expect(frase, endsWith('.'));
        // Duas frases: a primeira diz o que houve, a segunda o que acontece
        // agora. Erro sem saída é o que faz a Maria desistir do app.
        expect(frase.split('. ').length, greaterThanOrEqualTo(2), reason: frase);
      }
    });
  });

  group('nenhuma string em inglês chega à tela', () {
    // O gate original do plano falava em varredura de CI. Não existe ESLint
    // nem equivalente no monorepo, então a varredura é este teste — senão não
    // é gate.
    test('as frases do dicionário não têm inglês nem jargão técnico', () {
      for (final frase in [...HomeErrorCopy.all, HomeErrorCopy.recovered]) {
        _exigirPortugues(frase);
      }
    });

    test('todo erro emitido pelo bloc sai do dicionário — nada de literal solto',
        () async {
      // Corpus do que o SDK e as camadas de dados mandam de verdade, em inglês.
      const cruas = <String>[
        'Token not available',
        'Failed to start conversation',
        'Failed to send message',
        'Microphone permission denied',
        'Session closed unexpectedly',
        'WebSocket connection closed: 1006',
        'ClientException: Failed host lookup: api.elevenlabs.io',
        'SocketException: Connection failed (OS Error: Network is unreachable)',
        'Unhandled state',
        '',
      ];

      final repository = _FakeConversationRepository();
      addTearDown(repository.dispose);
      final bloc = _buildBloc(repository);
      addTearDown(bloc.close);

      final vistas = <String>[];
      final sub = bloc.stream.listen((state) {
        final message = state.errorMessage;
        if (message != null) vistas.add(message);
      });
      addTearDown(sub.cancel);

      bloc.add(const HomeInitEvent());
      await _tick();
      for (final crua in cruas) {
        repository.emitDrop(crua);
        await _tick();
        expect(bloc.state.errorMessage, isNotNull, reason: crua);
        if (crua.isNotEmpty) {
          expect(bloc.state.errorMessage, isNot(contains(crua)));
        }
      }

      // Os caminhos que não passam pelo `onError`: token, início e envio.
      final semToken = _FakeConversationRepository(
        tokenFailure: const Failure<String>(
          AppFailure.unexpected(message: 'Failed to fetch token'),
        ),
      );
      addTearDown(semToken.dispose);
      final blocSemToken = _buildBloc(semToken);
      addTearDown(blocSemToken.close);
      final subSemToken = blocSemToken.stream.listen((state) {
        final message = state.errorMessage;
        if (message != null) vistas.add(message);
      });
      addTearDown(subSemToken.cancel);
      blocSemToken.add(const HomeInitEvent());
      await _tick();
      blocSemToken.add(const HomeMicTappedEvent());
      await _tick();
      blocSemToken.add(const HomeTextSubmittedEvent('oi'));
      await _tick();

      final semInicio = _FakeConversationRepository(failStart: true);
      addTearDown(semInicio.dispose);
      final blocSemInicio = _buildBloc(semInicio);
      addTearDown(blocSemInicio.close);
      final subSemInicio = blocSemInicio.stream.listen((state) {
        final message = state.errorMessage;
        if (message != null) vistas.add(message);
      });
      addTearDown(subSemInicio.cancel);
      blocSemInicio.add(const HomeInitEvent());
      await _tick();
      blocSemInicio.add(const HomeMicTappedEvent());
      await _tick();

      final semEnvio = _FakeConversationRepository(failSend: true);
      addTearDown(semEnvio.dispose);
      final blocSemEnvio = _buildBloc(semEnvio);
      addTearDown(blocSemEnvio.close);
      final subSemEnvio = blocSemEnvio.stream.listen((state) {
        final message = state.errorMessage;
        if (message != null) vistas.add(message);
      });
      addTearDown(subSemEnvio.cancel);
      blocSemEnvio.add(const HomeInitEvent());
      await _tick();
      blocSemEnvio.add(const HomeTextSubmittedEvent('Tomei o remédio'));
      await _tick();

      expect(vistas, isNotEmpty);
      for (final vista in vistas) {
        expect(
          HomeErrorCopy.all,
          contains(vista),
          reason: 'mensagem fora do dicionário chegou à tela: "$vista"',
        );
        _exigirPortugues(vista);
      }
    });

    test('o bloc não escreve mensagem de erro à mão', () {
      final fonte = File(
        'lib/features/home/presentation/bloc/home_bloc.dart',
      ).readAsStringSync();

      final atribuicoes =
          RegExp(r'errorMessage:\s*(.*)').allMatches(fonte).toList();
      expect(atribuicoes, isNotEmpty);
      for (final atribuicao in atribuicoes) {
        expect(
          atribuicao.group(1),
          contains('HomeErrorCopy'),
          reason: 'erro montado fora do dicionário: "${atribuicao.group(0)}"',
        );
      }
    });
  });

  test('sem internet ao abrir o app, o primeiro toque fala de internet', () async {
    final repository = _FakeConversationRepository(
      tokenFailure: const Failure<String>(
        AppFailure.networkError(message: 'Failed host lookup'),
      ),
    );
    addTearDown(repository.dispose);
    final bloc = _buildBloc(repository);
    addTearDown(bloc.close);

    bloc.add(const HomeInitEvent());
    await _tick();
    // A tela abre calma: falha de rede na abertura não vira banner vermelho
    // antes de a Maria pedir alguma coisa.
    expect(bloc.state.errorMessage, isNull);

    bloc.add(const HomeMicTappedEvent());
    await _tick();

    expect(bloc.state.errorMessage, HomeErrorCopy.of(HomeErrorCode.network));
  });

  test('token indisponível por outro motivo mostra a frase do token', () async {
    final repository = _FakeConversationRepository(
      tokenFailure: const Failure<String>(
        AppFailure.unexpected(message: 'Empty token received'),
      ),
    );
    addTearDown(repository.dispose);
    final bloc = _buildBloc(repository);
    addTearDown(bloc.close);

    bloc.add(const HomeInitEvent());
    await _tick();
    bloc.add(const HomeMicTappedEvent());
    await _tick();

    expect(
      bloc.state.errorMessage,
      HomeErrorCopy.of(HomeErrorCode.tokenUnavailable),
    );
  });
}

/// Palavras que denunciam mensagem crua do SDK. `internet` fica de fora de
/// propósito: é a mesma palavra em português.
const List<String> _jargaoProibido = [
  'failed',
  'failure',
  'error',
  'unavailable',
  'not available',
  'token',
  'session',
  'connection',
  'connect',
  'network',
  'socket',
  'exception',
  'timeout',
  'timed out',
  'invalid',
  'unknown',
  'undefined',
  'request',
  'server',
  'microphone',
  'permission',
  'message',
  'try again',
  'please',
  'websocket',
  'livekit',
];

final RegExp _formatoDeCodigo = RegExp(r'[A-Za-z]+Exception|[a-z]+_[a-z]+|HTTP');

void _exigirPortugues(String frase) {
  final minuscula = frase.toLowerCase();
  for (final termo in _jargaoProibido) {
    expect(
      minuscula.contains(termo),
      isFalse,
      reason: 'jargão em inglês ("$termo") na frase: "$frase"',
    );
  }
  expect(
    _formatoDeCodigo.hasMatch(frase),
    isFalse,
    reason: 'formato de código na frase: "$frase"',
  );
}

Future<void> _tick() => Future<void>.delayed(const Duration(milliseconds: 20));

HomeBloc _buildBloc(_FakeConversationRepository repository) {
  return HomeBloc(
    fetchTokenUseCase: FetchConversationTokenUseCase(repository),
    startConversationUseCase: StartConversationUseCase(repository),
    stopConversationUseCase: StopConversationUseCase(repository),
    sendTextMessageUseCase: SendTextMessageUseCase(repository),
    toggleMuteUseCase: ToggleMuteUseCase(repository),
    conversationRepository: repository,
    // Quem controla o tempo aqui é o teste: a espera por silêncio não pode
    // disparar no meio de um caso de erro.
    silenceTimeout: const Duration(days: 1),
  );
}

/// Sessão de conversa de mentira que reproduz o comportamento observável da
/// real — inclusive o detalhe que importa aqui: o SDK reporta a queda pelo
/// callback `onError`, em inglês, junto com o status de erro.
class _FakeConversationRepository implements ConversationRepository {
  _FakeConversationRepository({
    this.tokenFailure,
    this.failStart = false,
    this.failSend = false,
  });

  final Result<String>? tokenFailure;
  final bool failStart;
  final bool failSend;

  final _status = StreamController<ConversationStatus>.broadcast();
  final _mode = StreamController<ConversationMode>.broadcast();
  final _muted = StreamController<bool>.broadcast();
  final _transcript =
      StreamController<List<TranscriptMessageEntity>>.broadcast();
  final _errors = StreamController<String>.broadcast();

  List<TranscriptMessageEntity> _messages = [];

  @override
  Stream<ConversationStatus> get statusStream => _status.stream;

  @override
  Stream<ConversationMode> get modeStream => _mode.stream;

  @override
  Stream<bool> get isMutedStream => _muted.stream;

  @override
  Stream<List<TranscriptMessageEntity>> get transcriptStream =>
      _transcript.stream;

  @override
  Stream<String> get errorStream => _errors.stream;

  @override
  Future<Result<String>> fetchToken() async =>
      tokenFailure ?? const Success('token-de-teste');

  @override
  Future<Result<void>> startConversation(String token) async {
    if (failStart) {
      return const Failure(AppFailure.unexpected(message: 'boom'));
    }
    _status.add(ConversationStatus.connected);
    _muted.add(false);
    return const Success(null);
  }

  @override
  Future<Result<void>> stopConversation() async {
    _status.add(ConversationStatus.disconnected);
    return const Success(null);
  }

  @override
  Future<Result<void>> setMicMuted(bool muted) async {
    _muted.add(muted);
    return const Success(null);
  }

  @override
  Future<Result<void>> sendTextMessage(String text) async {
    if (failSend) {
      return const Failure(AppFailure.unexpected(message: 'boom'));
    }
    _append(TranscriptMessageEntity(text: text, isUser: true));
    return const Success(null);
  }

  /// Queda da sessão do jeito que a real acontece: status de erro primeiro,
  /// mensagem crua em inglês em seguida.
  void emitDrop(String rawMessage) {
    _status.add(ConversationStatus.error);
    _errors.add(rawMessage);
  }

  /// A conexão volta sem ninguém tocar em nada.
  void emitReconnected() => _status.add(ConversationStatus.connected);

  void emitAuraMessage(String text) {
    _append(TranscriptMessageEntity(text: text, isUser: false));
  }

  void _append(TranscriptMessageEntity message) {
    _messages = [..._messages, message];
    _transcript.add(_messages);
  }

  void dispose() {
    _status.close();
    _mode.close();
    _muted.close();
    _transcript.close();
    _errors.close();
  }
}
