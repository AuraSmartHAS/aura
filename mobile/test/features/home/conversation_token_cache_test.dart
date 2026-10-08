import 'package:aura/core/errors/app_failure.dart';
import 'package:aura/core/errors/result.dart';
import 'package:aura/features/home/domain/conversation_token_cache.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

/// Busca de token de mentira: cada chamada devolve um token diferente, como a
/// ElevenLabs (o token é de uso único).
class _Fetcher {
  int calls = 0;
  bool fail = false;

  Future<Result<String>> call() async {
    calls++;
    if (fail) {
      return const Failure(AppFailure.networkError(message: 'x'));
    }
    return Success('token-$calls');
  }
}

void main() {
  test('o token da abertura serve à primeira conversa; as seguintes buscam na '
      'hora e nada é buscado de antemão', () async {
    final fetch = _Fetcher();
    final cache = ConversationTokenCache(fetch.call)..warmUp();
    await Future<void>.delayed(Duration.zero);
    expect(fetch.calls, 1);

    final primeiro = await cache.take();
    expect((primeiro as Success<String>).data, 'token-1');
    // cada token emitido ocupa uma vaga na ElevenLabs: nada de buscar o próximo
    await Future<void>.delayed(Duration.zero);
    expect(fetch.calls, 1);

    final segundo = await cache.take();
    expect((segundo as Success<String>).data, 'token-2');
    expect(fetch.calls, 2);
  });

  test('warmUp repetido não busca outro token enquanto há um guardado', () async {
    final fetch = _Fetcher();
    final cache = ConversationTokenCache(fetch.call)..warmUp();
    await Future<void>.delayed(Duration.zero);

    cache
      ..warmUp()
      ..warmUp();
    await Future<void>.delayed(Duration.zero);

    expect(fetch.calls, 1);
  });

  test('token guardado há mais de 13 min não é usado: busca outro na hora', () {
    fakeAsync((async) {
      var agora = DateTime(2026, 10, 8, 11);
      final fetch = _Fetcher();
      final cache = ConversationTokenCache(fetch.call, now: () => agora)
        ..warmUp();
      async.flushMicrotasks();

      agora = agora.add(const Duration(minutes: 14));
      String? usado;
      cache.take().then((r) => usado = (r as Success<String>).data);
      async.flushMicrotasks();

      expect(usado, 'token-2', reason: 'o token-1 estaria perto de vencer');
    });
  });

  test('o toque durante a busca da abertura espera essa busca, sem outra',
      () async {
    final fetch = _Fetcher();
    final cache = ConversationTokenCache(fetch.call)..warmUp();

    final resultado = await cache.take();

    expect((resultado as Success<String>).data, 'token-1');
    expect(fetch.calls, 1);
  });

  test('falha na busca da abertura é silenciosa e o toque busca na hora',
      () async {
    final fetch = _Fetcher()..fail = true;
    final cache = ConversationTokenCache(fetch.call)..warmUp();
    await Future<void>.delayed(Duration.zero);

    fetch.fail = false;
    final resultado = await cache.take();

    expect((resultado as Success<String>).data, 'token-2');
  });
}
