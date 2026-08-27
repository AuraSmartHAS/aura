import 'package:aura/core/errors/result.dart';
import 'package:aura/features/home/data/datasources/conversation_session_datasource.dart';
import 'package:aura/features/home/domain/entities/transcript_message_entity.dart';
import 'package:elevenlabs_agents/elevenlabs_agents.dart' as sdk;
import 'package:flutter_test/flutter_test.dart';

/// Correção C4 — o caminho de texto na camada de dados.
///
/// O método do SDK chama-se `sendUserMessage(String)` e é **void**: ele não
/// devolve Future e não lança quando o envio falha depois de conectado — o erro
/// volta pelo callback `onError`. Estes testes prendem as duas metades.
void main() {
  test('sendText entrega o texto ao sendUserMessage do SDK e entra no '
      'transcript como mensagem da Maria', () async {
    final client = _FakeConversationClient();
    final dataSource = ConversationSessionDataSourceImpl(
      clientFactory: (callbacks) => client..captured = callbacks,
    );
    addTearDown(dataSource.dispose);

    final transcripts = <List<TranscriptMessageEntity>>[];
    final subscription = dataSource.transcriptStream.listen(transcripts.add);
    addTearDown(subscription.cancel);

    final result = await dataSource.sendText('  Tomei o remédio  ');
    await Future<void>.delayed(Duration.zero);

    expect(result, isA<Success<void>>());
    expect(client.sent, ['Tomei o remédio']);
    expect(transcripts.last.last.text, 'Tomei o remédio');
    expect(transcripts.last.last.isUser, isTrue);
  });

  test('sem sessão viva o envio falha em vez de sumir em silêncio', () async {
    final client = _FakeConversationClient(connected: false);
    final dataSource = ConversationSessionDataSourceImpl(
      clientFactory: (callbacks) => client..captured = callbacks,
    );
    addTearDown(dataSource.dispose);

    final result = await dataSource.sendText('Estou com dor');

    expect(result, isA<Failure<void>>());
    expect(client.sent, isEmpty);
  });

  test('erro reportado pelo onError sai pelo errorStream', () async {
    final client = _FakeConversationClient();
    final dataSource = ConversationSessionDataSourceImpl(
      clientFactory: (callbacks) => client..captured = callbacks,
    );
    addTearDown(dataSource.dispose);

    final errors = <String>[];
    final subscription = dataSource.errorStream.listen(errors.add);
    addTearDown(subscription.cancel);

    // É assim que o SDK avisa: pelo callback, não por exceção.
    client.captured.onError!('Failed to send message', null);
    await Future<void>.delayed(Duration.zero);

    expect(errors, ['Failed to send message']);
  });
}

/// Cliente do SDK sem LiveKit: registra o texto enviado e guarda os callbacks
/// que o datasource montou, para o teste poder disparar o `onError`.
class _FakeConversationClient extends sdk.ConversationClient {
  _FakeConversationClient({this.connected = true});

  final bool connected;
  final List<String> sent = [];
  late sdk.ConversationCallbacks captured;

  @override
  void sendUserMessage(String text) {
    if (!connected) {
      // Mesmo comportamento do `_ensureConnected()` do SDK.
      throw StateError('Not connected to agent');
    }
    sent.add(text);
  }
}
