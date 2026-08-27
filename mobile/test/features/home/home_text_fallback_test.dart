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
import 'package:aura/features/home/presentation/widgets/home_body.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

/// Correção C4 — fallback não-vocal real.
///
/// Até 89% das pessoas com Parkinson têm distúrbio de fala: para elas o
/// "Prefiro digitar" não é atalho, é o caminho principal. O achado CR-2 da
/// auditoria era que esse botão ligava o microfone.
void main() {
  testWidgets(
      'R-10 — "Prefiro digitar" não dispara o evento do microfone e conecta '
      'com o microfone mudo', (tester) async {
    final repository = _FakeConversationRepository();
    addTearDown(repository.dispose);
    final bloc = _RecordingHomeBloc(repository);
    // `Bloc.close()` não completa dentro do FakeAsync do testWidgets: o
    // encerramento vai para o teardown, que roda em tempo real.
    addTearDown(bloc.close);

    await _pumpHome(tester, bloc);

    await tester.tap(find.text('Prefiro digitar'));
    await _settle(tester);

    // O bug que esta correção conserta: o botão do teclado despachava
    // HomeMicTappedEvent. Se alguém copiar o padrão de novo, este teste cai.
    expect(bloc.recorded.whereType<HomeMicTappedEvent>(), isEmpty);
    expect(bloc.recorded.whereType<HomeTextModeRequestedEvent>(), isNotEmpty);

    // Conectar liga o microfone: no caminho escrito ele nasce mudo, senão
    // "usar sem falar" ainda passa pela permissão do microfone.
    expect(repository.muteCalls, contains(true));
    expect(bloc.state.isMuted, isTrue);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('a mensagem digitada é enviada e aparece no transcript',
      (tester) async {
    final repository = _FakeConversationRepository();
    addTearDown(repository.dispose);
    final bloc = _RecordingHomeBloc(repository);
    // `Bloc.close()` não completa dentro do FakeAsync do testWidgets: o
    // encerramento vai para o teardown, que roda em tempo real.
    addTearDown(bloc.close);

    await _pumpHome(tester, bloc);
    await tester.tap(find.text('Prefiro digitar'));
    await _settle(tester);

    await tester.enterText(find.byType(TextField), 'Estou bem hoje');
    await tester.tap(find.byIcon(Icons.send));
    await _settle(tester);

    expect(repository.sentTexts, ['Estou bem hoje']);
    expect(find.text('Estou bem hoje'), findsOneWidget);
    expect(find.text('Você'), findsOneWidget);
  });

  testWidgets('um chip de intenção envia a frase correspondente',
      (tester) async {
    final repository = _FakeConversationRepository();
    addTearDown(repository.dispose);
    final bloc = _RecordingHomeBloc(repository);
    // `Bloc.close()` não completa dentro do FakeAsync do testWidgets: o
    // encerramento vai para o teardown, que roda em tempo real.
    addTearDown(bloc.close);

    await _pumpHome(tester, bloc);
    await tester.tap(find.text('Prefiro digitar'));
    await _settle(tester);

    await tester.tap(find.text('Tomei o remédio'));
    await _settle(tester);

    expect(repository.sentTexts, ['Tomei o remédio']);
  });

  testWidgets('erro de envio chega pelo onError e vira frase em português',
      (tester) async {
    final repository = _FakeConversationRepository();
    addTearDown(repository.dispose);
    final bloc = _RecordingHomeBloc(repository);
    // `Bloc.close()` não completa dentro do FakeAsync do testWidgets: o
    // encerramento vai para o teardown, que roda em tempo real.
    addTearDown(bloc.close);

    await _pumpHome(tester, bloc);

    // O SDK não lança no envio: avisa pelo callback onError, em inglês.
    repository.emitError('Failed to send message');
    await _settle(tester);

    expect(
      find.text('Não consegui enviar sua mensagem. Tente de novo.'),
      findsOneWidget,
    );
  });

  test('sem resposta na conversa, a Aura avisa e destaca as frases prontas',
      () async {
    final repository = _FakeConversationRepository();
    addTearDown(repository.dispose);
    final bloc = _buildBloc(
      repository,
      silenceTimeout: const Duration(milliseconds: 50),
    );

    bloc.add(const HomeInitEvent());
    await _tick();
    bloc.add(const HomeMicTappedEvent());
    await _tick();
    expect(bloc.state.voiceState, VoiceUIState.listening);

    final deadline = DateTime.now().add(const Duration(seconds: 3));
    while (bloc.state.notice == null && DateTime.now().isBefore(deadline)) {
      await _tick();
    }

    expect(bloc.state.notice, contains('Não te ouvi'));
    expect(bloc.state.intentsHighlighted, isTrue);

    await bloc.close();
  });

  test('duas falhas seguidas levam a Maria ao caminho não-vocal', () async {
    final repository = _FakeConversationRepository();
    addTearDown(repository.dispose);
    // Espera longa: quem conta as falhas aqui é o teste, não o relógio.
    final bloc = _buildBloc(repository, silenceTimeout: const Duration(days: 1));

    bloc.add(const HomeInitEvent());
    await _tick();

    bloc.add(const HomeSilenceDetectedEvent());
    await _tick();
    expect(bloc.state.intentsHighlighted, isTrue);
    expect(bloc.state.isTextMode, isFalse);

    bloc.add(const HomeSilenceDetectedEvent());
    await _tick();
    expect(bloc.state.isTextMode, isTrue);
    expect(bloc.state.notice, contains('escreva'));
    expect(repository.muteCalls.last, isTrue);

    await bloc.close();
  });

  test('"Ouvir de novo" traz de volta a última fala da Aura', () async {
    final repository = _FakeConversationRepository();
    addTearDown(repository.dispose);
    final bloc = _buildBloc(repository);

    bloc.add(const HomeInitEvent());
    await _tick();

    repository.emitAuraMessage('Está na hora do seu remédio.');
    await _tick();

    bloc.add(const HomeRepeatLastReplyEvent());
    await _tick();

    expect(bloc.state.notice, 'Está na hora do seu remédio.');

    await bloc.close();
  });
}

Future<void> _tick() => Future<void>.delayed(const Duration(milliseconds: 20));

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 10));
  }
}

Future<void> _pumpHome(WidgetTester tester, HomeBloc bloc) async {
  await tester.pumpWidget(
    MaterialApp(
      home: BlocProvider<HomeBloc>.value(
        value: bloc..add(const HomeInitEvent()),
        child: const HomeBody(),
      ),
    ),
  );
  await _settle(tester);
}

HomeBloc _buildBloc(
  _FakeConversationRepository repository, {
  Duration silenceTimeout = const Duration(seconds: 12),
}) {
  return HomeBloc(
    fetchTokenUseCase: FetchConversationTokenUseCase(repository),
    startConversationUseCase: StartConversationUseCase(repository),
    stopConversationUseCase: StopConversationUseCase(repository),
    sendTextMessageUseCase: SendTextMessageUseCase(repository),
    toggleMuteUseCase: ToggleMuteUseCase(repository),
    conversationRepository: repository,
    silenceTimeout: silenceTimeout,
  );
}

/// Bloc que guarda os eventos recebidos — é o que permite afirmar que um botão
/// **não** disparou determinado evento.
class _RecordingHomeBloc extends HomeBloc {
  _RecordingHomeBloc(_FakeConversationRepository repository)
      : super(
          fetchTokenUseCase: FetchConversationTokenUseCase(repository),
          startConversationUseCase: StartConversationUseCase(repository),
          stopConversationUseCase: StopConversationUseCase(repository),
          sendTextMessageUseCase: SendTextMessageUseCase(repository),
          toggleMuteUseCase: ToggleMuteUseCase(repository),
          conversationRepository: repository,
          silenceTimeout: const Duration(days: 1),
        );

  final List<HomeEvent> recorded = [];

  @override
  void add(HomeEvent event) {
    recorded.add(event);
    super.add(event);
  }
}

/// Sessão de conversa de mentira, com o mesmo comportamento observável da real:
/// conectar liga o microfone, e o texto enviado entra no transcript como
/// mensagem da paciente.
class _FakeConversationRepository implements ConversationRepository {
  final _status = StreamController<ConversationStatus>.broadcast();
  final _mode = StreamController<ConversationMode>.broadcast();
  final _muted = StreamController<bool>.broadcast();
  final _transcript =
      StreamController<List<TranscriptMessageEntity>>.broadcast();
  final _errors = StreamController<String>.broadcast();

  final List<String> sentTexts = [];
  final List<bool> muteCalls = [];
  bool failSend = false;

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
  Future<Result<String>> fetchToken() async => const Success('token-de-teste');

  @override
  Future<Result<void>> startConversation(String token) async {
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
    muteCalls.add(muted);
    _muted.add(muted);
    return const Success(null);
  }

  @override
  Future<Result<void>> sendTextMessage(String text) async {
    if (failSend) {
      return const Failure(AppFailure.unexpected(message: 'falhou'));
    }
    sentTexts.add(text);
    _append(TranscriptMessageEntity(text: text, isUser: true));
    return const Success(null);
  }

  void emitAuraMessage(String text) {
    _append(TranscriptMessageEntity(text: text, isUser: false));
  }

  void emitError(String message) => _errors.add(message);

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
