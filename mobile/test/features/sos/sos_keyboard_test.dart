import 'dart:async';

import 'package:aura/core/errors/result.dart';
import 'package:aura/core/theme/app_dimensions.dart';
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
import 'package:aura/features/sos/presentation/widgets/sos_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

/// Correções C3 + C4 — o bug que as duas criam juntas.
///
/// C4 pôs um campo de texto no rodapé da tela de voz; C3 põe o botão de
/// socorro na mesma tela. Se o SOS morasse no rodapé, o teclado aberto o
/// empurraria para fora ou o cobriria — e uma pessoa que caiu no banheiro com o
/// teclado aberto ficaria sem caminho de ajuda. Por isso ele está ancorado no
/// alto: com o teclado aberto, quem encolhe é o rodapé.
void main() {
  const double alturaDoTeclado = 320;

  testWidgets('o teclado aberto não cobre nem empurra o botão SOS',
      (tester) async {
    final repository = _FakeConversationRepository();
    addTearDown(repository.dispose);
    final bloc = _buildBloc(repository);

    // O caminho escrito aberto é o cenário do bug: rodapé no tamanho máximo.
    await _pumpHome(tester, bloc);
    await tester.tap(find.text('Prefiro digitar'));
    await _settle(tester);
    expect(find.byType(TextField), findsOneWidget);

    final semTeclado = tester.getRect(find.byType(SosButton));

    await _pumpHome(tester, bloc, keyboardInset: alturaDoTeclado);
    await _settle(tester);

    final comTeclado = tester.getRect(find.byType(SosButton));
    final alturaDaTela = tester.view.physicalSize.height /
        tester.view.devicePixelRatio;

    // Não foi empurrado: o botão está exatamente onde estava.
    expect(comTeclado, semTeclado);

    // Não foi coberto: termina bem acima da borda de cima do teclado.
    expect(comTeclado.bottom, lessThan(alturaDaTela - alturaDoTeclado));

    // Continua inteiro na tela e no tamanho de alvo que a correção exige.
    expect(comTeclado.top, greaterThanOrEqualTo(0));
    expect(comTeclado.width, greaterThanOrEqualTo(AppDimensions.sosButtonSize));
    expect(
      comTeclado.height,
      greaterThanOrEqualTo(AppDimensions.sosButtonSize),
    );

    // E o rodapé encolhendo não estourou nada.
    expect(tester.takeException(), isNull);

    await _stop(tester, bloc);
  });

  testWidgets('o botão SOS continua alcançável com a fonte do sistema no '
      'máximo e o teclado aberto', (tester) async {
    final repository = _FakeConversationRepository();
    addTearDown(repository.dispose);
    final bloc = _buildBloc(repository);

    await _pumpHome(
      tester,
      bloc,
      keyboardInset: alturaDoTeclado,
      textScale: 1.3,
    );
    await tester.tap(find.text('Prefiro digitar'));
    await _settle(tester);

    final sos = tester.getRect(find.byType(SosButton));
    final alturaDaTela = tester.view.physicalSize.height /
        tester.view.devicePixelRatio;

    expect(sos.bottom, lessThan(alturaDaTela - alturaDoTeclado));
    expect(tester.takeException(), isNull);

    await _stop(tester, bloc);
  });
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}

/// Encerra o bloc dentro do teste de widget: `close()` não completa no relógio
/// falso, mas o que precisa morrer morre na primeira linha dele.
Future<void> _stop(WidgetTester tester, HomeBloc bloc) async {
  unawaited(bloc.close());
  await tester.pump();
}

Future<void> _pumpHome(
  WidgetTester tester,
  HomeBloc bloc, {
  double keyboardInset = 0,
  double textScale = 1,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        // Parte da tela de verdade e muda só o que o teclado muda: é assim que
        // o sistema conta que ele subiu — o Scaffold encolhe o corpo pelo
        // `viewInsets`.
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            viewInsets: EdgeInsets.only(bottom: keyboardInset),
            textScaler: TextScaler.linear(textScale),
          ),
          child: BlocProvider<HomeBloc>.value(
            value: bloc..add(const HomeInitEvent()),
            child: const HomeBody(),
          ),
        ),
      ),
    ),
  );
  await _settle(tester);
}

HomeBloc _buildBloc(_FakeConversationRepository repository) {
  return HomeBloc(
    fetchTokenUseCase: FetchConversationTokenUseCase(repository),
    startConversationUseCase: StartConversationUseCase(repository),
    stopConversationUseCase: StopConversationUseCase(repository),
    sendTextMessageUseCase: SendTextMessageUseCase(repository),
    toggleMuteUseCase: ToggleMuteUseCase(repository),
    conversationRepository: repository,
    // Quem manda no tempo aqui é o teste: a espera por silêncio não interessa.
    silenceTimeout: const Duration(days: 1),
  );
}

/// Sessão de conversa de mentira — só o que este teste de layout precisa.
class _FakeConversationRepository implements ConversationRepository {
  final _status = StreamController<ConversationStatus>.broadcast();
  final _mode = StreamController<ConversationMode>.broadcast();
  final _muted = StreamController<bool>.broadcast();
  final _transcript =
      StreamController<List<TranscriptMessageEntity>>.broadcast();
  final _errors = StreamController<String>.broadcast();

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
    _muted.add(muted);
    return const Success(null);
  }

  @override
  Future<Result<void>> sendTextMessage(String text) async =>
      const Success(null);

  void dispose() {
    _status.close();
    _mode.close();
    _muted.close();
    _transcript.close();
    _errors.close();
  }
}
