import 'dart:async';

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

/// Correção C7a — cada conversa com o seu token.
///
/// O token da conversa é de **uso único**: o app buscava um só na abertura da
/// tela e reusava, então a segunda conversa na mesma tela não subia. É o bug
/// que estraga gravação de demonstração, porque quem grava precisa de mais de
/// uma tomada.
///
/// Agora a tela busca **um** token na abertura (a ElevenLabs leva segundos
/// para gerar um), mas ele continua servindo a uma conversa só: a primeira o
/// consome, e as seguintes buscam o seu na hora. Nada é buscado de antemão
/// além desse — cada token emitido ocupa uma vaga de conversa na ElevenLabs.
void main() {
  test(
      'duas conversas seguidas na mesma tela funcionam — e cada uma busca o '
      'seu token', () async {
    final repository = _FakeConversationRepository();
    addTearDown(repository.dispose);
    final bloc = _buildBloc(repository);
    addTearDown(bloc.close);

    bloc.add(const HomeInitEvent());
    await _tick();
    // Abrir a tela já deixa um token pronto, para o toque não esperar.
    expect(repository.tokenFetches, 1);
    expect(repository.startedWith, isEmpty);

    // Primeira conversa: usa o token guardado, sem buscar outro.
    bloc.add(const HomeMicTappedEvent());
    await _tick();
    expect(bloc.state.voiceState, VoiceUIState.listening);
    expect(repository.startedWith, ['token-1']);
    expect(repository.tokenFetches, 1);

    // Ela encerra.
    bloc.add(const HomeMicTappedEvent());
    await _tick();
    expect(bloc.state.voiceState, VoiceUIState.idle);

    // Segunda conversa, sem sair da tela — o que quebrava antes.
    bloc.add(const HomeMicTappedEvent());
    await _tick();

    expect(
      repository.startedWith,
      ['token-1', 'token-2'],
      reason: 'cada conversa precisa do seu token, não do anterior',
    );
    expect(bloc.state.voiceState, VoiceUIState.listening);
    expect(bloc.state.errorMessage, isNull);
  });

  test('falha ao buscar o token vira frase do dicionário, em português',
      () async {
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
    // A busca antecipada falhou, mas a tela abre calma: o erro só aparece
    // quando a Maria pede para falar.
    expect(bloc.state.errorMessage, isNull);

    bloc.add(const HomeMicTappedEvent());
    await _tick();

    expect(
      bloc.state.errorMessage,
      HomeErrorCopy.of(HomeErrorCode.tokenUnavailable),
    );
    expect(
      HomeErrorCopy.all,
      contains(bloc.state.errorMessage),
      reason: 'mensagem fora do dicionário chegou à tela',
    );
    expect(bloc.state.errorMessage, isNot(contains('token')));
    // Sem sessão: o microfone não pode ficar preso em "Conectando...", porque a
    // frase manda tocar de novo.
    expect(bloc.state.voiceState, VoiceUIState.error);
    expect(repository.startedWith, isEmpty);

    // E o toque seguinte tenta buscar de novo — é o que a frase promete.
    final antes = repository.tokenFetches;
    bloc.add(const HomeMicTappedEvent());
    await _tick();
    expect(repository.tokenFetches, greaterThan(antes));
  });

  test('toque duplo rápido no microfone não dispara duas buscas de token',
      () async {
    // Busca lenta de propósito: garante que o segundo toque cai no meio da
    // primeira. Com Parkinson, o toque dobrado é regra, não exceção.
    final repository = _FakeConversationRepository(
      fetchDelay: const Duration(milliseconds: 80),
    );
    addTearDown(repository.dispose);
    final bloc = _buildBloc(repository);
    addTearDown(bloc.close);

    bloc.add(const HomeInitEvent());
    await _tick();

    // Os dois toques caem com a busca antecipada ainda em curso: os dois
    // esperam essa mesma busca, nenhum começa outra.
    bloc.add(const HomeMicTappedEvent());
    bloc.add(const HomeMicTappedEvent());

    await _waitFor(() => bloc.state.voiceState == VoiceUIState.listening);
    await _tick();

    // Só a busca da abertura, usada pela conversa que subiu.
    expect(repository.tokenFetches, 1, reason: 'busca concorrente a mais');
    expect(repository.startedWith, ['token-1']);
    // O segundo toque também não pode ter derrubado a conversa que subia — era
    // o que acontecia: ele caía no caminho de "encerrar".
    expect(repository.stopCalls, 0);
    expect(bloc.state.voiceState, VoiceUIState.listening);
    expect(bloc.state.errorMessage, isNull);
  });

  test(
      'frase tocada no meio da conexão espera a conversa que já sobe, sem '
      'buscar um segundo token', () async {
    final repository = _FakeConversationRepository(
      fetchDelay: const Duration(milliseconds: 80),
    );
    addTearDown(repository.dispose);
    final bloc = _buildBloc(repository);
    addTearDown(bloc.close);

    bloc.add(const HomeInitEvent());
    await _tick();

    // Microfone tocado e, antes de conectar, ela desiste de falar e toca numa
    // frase pronta. São dois caminhos pedindo conversa ao mesmo tempo.
    bloc.add(const HomeMicTappedEvent());
    bloc.add(const HomeTextSubmittedEvent('Estou com dor'));

    await _waitFor(() => repository.sentTexts.isNotEmpty);
    await _tick();

    // Só a busca da abertura, usada pela conversa que subiu.
    expect(repository.tokenFetches, 1, reason: 'busca concorrente a mais');
    expect(repository.startedWith, hasLength(1));
    // O texto não pode se perder por causa da espera.
    expect(repository.sentTexts, ['Estou com dor']);
  });

  test('o caminho escrito também sobe cada sessão com token novo', () async {
    final repository = _FakeConversationRepository();
    addTearDown(repository.dispose);
    final bloc = _buildBloc(repository);
    addTearDown(bloc.close);

    bloc.add(const HomeInitEvent());
    await _tick();
    bloc.add(const HomeTextModeRequestedEvent());
    await _tick();

    expect(repository.startedWith, ['token-1']);
    expect(bloc.state.isMuted, isTrue);

    // A sessão cai (aparelho dormiu, internet oscilou) e ela escreve de novo.
    repository.emitDisconnected();
    await _tick();
    bloc.add(const HomeTextSubmittedEvent('Tomei o remédio'));
    await _tick();

    expect(repository.startedWith, ['token-1', 'token-2']);
    expect(repository.sentTexts, ['Tomei o remédio']);
  });

  test('com o token já buscado, o toque conecta sem esperar a ElevenLabs',
      () async {
    // Cada busca de token leva 300 ms (na vida real, de 3 a 16 s).
    final repository = _FakeConversationRepository(
      fetchDelay: const Duration(milliseconds: 300),
    );
    addTearDown(repository.dispose);
    final bloc = _buildBloc(repository);
    addTearDown(bloc.close);

    bloc.add(const HomeInitEvent());
    await _waitFor(() => repository.tokenFetches == 1);
    await Future<void>.delayed(const Duration(milliseconds: 400));

    final toque = DateTime.now();
    bloc.add(const HomeMicTappedEvent());
    await _waitFor(() => repository.startedWith.isNotEmpty);

    expect(repository.startedWith, ['token-1']);
    expect(
      DateTime.now().difference(toque),
      lessThan(const Duration(milliseconds: 200)),
      reason: 'o toque esperou uma busca de token que já devia estar pronta',
    );
  });

  test('a saudação sai na primeira interação e não volta, nem se a tentativa '
      'falhar; a tela recriada lembra', () async {
    final repository = _FakeConversationRepository(
      tokenFailure: const Failure<String>(
        AppFailure.networkError(message: 'sem rede'),
      ),
    );
    addTearDown(repository.dispose);
    var lembrado = false;
    HomeBloc nova() => HomeBloc(
          fetchTokenUseCase: FetchConversationTokenUseCase(repository),
          startConversationUseCase: StartConversationUseCase(repository),
          stopConversationUseCase: StopConversationUseCase(repository),
          sendTextMessageUseCase: SendTextMessageUseCase(repository),
          toggleMuteUseCase: ToggleMuteUseCase(repository),
          conversationRepository: repository,
          silenceTimeout: const Duration(days: 1),
          greetingDismissedBefore: () => lembrado,
          onGreetingDismissed: () => lembrado = true,
        );

    final bloc = nova();
    addTearDown(bloc.close);
    bloc.add(const HomeInitEvent());
    await _tick();
    expect(bloc.state.greetingDismissed, isFalse);

    bloc.add(const HomeMicTappedEvent());
    await _tick();

    // falhou: a saudação continua fora e o erro existe para ocupar o lugar
    // da explicação
    expect(bloc.state.voiceState, VoiceUIState.error);
    expect(bloc.state.greetingDismissed, isTrue);
    expect(bloc.state.errorMessage, isNotNull);
    expect(lembrado, isTrue);

    // a tela é recriada (foi ao menu e voltou): a saudação não reaparece
    final outra = nova();
    addTearDown(outra.close);
    outra.add(const HomeInitEvent());
    await _tick();
    expect(outra.state.greetingDismissed, isTrue);
  });
}

Future<void> _tick() => Future<void>.delayed(const Duration(milliseconds: 20));

/// Espera uma condição sem prender o teste num tempo fixo.
Future<void> _waitFor(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 3));
  while (!condition() && DateTime.now().isBefore(deadline)) {
    await _tick();
  }
}

HomeBloc _buildBloc(_FakeConversationRepository repository) {
  return HomeBloc(
    fetchTokenUseCase: FetchConversationTokenUseCase(repository),
    startConversationUseCase: StartConversationUseCase(repository),
    stopConversationUseCase: StopConversationUseCase(repository),
    sendTextMessageUseCase: SendTextMessageUseCase(repository),
    toggleMuteUseCase: ToggleMuteUseCase(repository),
    conversationRepository: repository,
    // A espera por silêncio não tem nada a ver com este teste.
    silenceTimeout: const Duration(days: 1),
  );
}

/// Conversa de mentira com a regra que quebrava a demonstração: **o token é de
/// uso único**. Reusar o da conversa anterior falha aqui, como falha na
/// ElevenLabs — cada `fetchToken` devolve um token diferente.
class _FakeConversationRepository implements ConversationRepository {
  _FakeConversationRepository({
    this.tokenFailure,
    this.fetchDelay = Duration.zero,
  });

  final Result<String>? tokenFailure;
  final Duration fetchDelay;

  int tokenFetches = 0;
  int stopCalls = 0;
  final List<String> startedWith = [];
  final List<String> sentTexts = [];
  final Set<String> _spentTokens = {};

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
  Future<Result<String>> fetchToken() async {
    tokenFetches++;
    await Future<void>.delayed(fetchDelay);
    return tokenFailure ?? Success('token-$tokenFetches');
  }

  @override
  Future<Result<void>> startConversation(String token) async {
    startedWith.add(token);
    if (!_spentTokens.add(token)) {
      // O que a ElevenLabs responde a um token já gasto.
      return const Failure(
        AppFailure.unauthorized(message: 'Conversation token already used'),
      );
    }
    _status.add(ConversationStatus.connected);
    _muted.add(false);
    return const Success(null);
  }

  @override
  Future<Result<void>> stopConversation() async {
    stopCalls++;
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
    sentTexts.add(text);
    _messages = [..._messages, TranscriptMessageEntity(text: text, isUser: true)];
    _transcript.add(_messages);
    return const Success(null);
  }

  /// A sessão cai sozinha, sem ninguém encerrar.
  void emitDisconnected() => _status.add(ConversationStatus.disconnected);

  void dispose() {
    _status.close();
    _mode.close();
    _muted.close();
    _transcript.close();
    _errors.close();
  }
}
