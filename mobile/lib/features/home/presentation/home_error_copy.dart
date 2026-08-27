/// O que deu errado, do ponto de vista da Maria.
///
/// Não é o erro técnico: é a categoria que muda **o que ela faz agora**. Dois
/// problemas diferentes no servidor que pedem o mesmo gesto dela são o mesmo
/// código aqui.
enum HomeErrorCode {
  /// Não deu para preparar a conversa antes de começar (token da sessão).
  tokenUnavailable,

  /// A conversa não subiu quando ela tocou no microfone.
  startFailed,

  /// A mensagem escrita não chegou até a Aura.
  sendFailed,

  /// A conversa estava de pé e caiu.
  connectionLost,

  /// Sem internet — modo avião, Wi-Fi fora do ar, sinal que sumiu.
  network,

  /// O microfone não pôde ser usado (permissão negada, aparelho ocupado).
  microphone,

  /// Nenhuma das anteriores. Ainda assim tem frase e tem saída.
  unknown,
}

/// Textos de erro e de recuperação da tela da Maria, num lugar só.
///
/// Correção C6: nenhuma exceção crua chega a um `Text`. A tela é de uma pessoa
/// de 74 anos com Parkinson — inglês com jargão ("Token not available") lê como
/// "o aparelho quebrou", e quem lê isso para de usar o app.
///
/// Duas regras que valem para toda frase daqui:
/// 1. diz **o que houve** e **o que vai acontecer** — nunca só o que falhou;
/// 2. nenhuma promessa que o app não cumpre (não existe retry automático nesta
///    versão, então nenhuma frase promete um).
class HomeErrorCopy {
  const HomeErrorCopy._();

  static const Map<HomeErrorCode, String> _messages = {
    HomeErrorCode.tokenUnavailable:
        'Não consegui me conectar agora. Toque no microfone que eu tento de '
            'novo.',
    HomeErrorCode.startFailed:
        'A conversa não começou. Toque no microfone que eu tento outra vez.',
    HomeErrorCode.sendFailed:
        'Sua mensagem não saiu. Toque em enviar de novo, que eu recebo.',
    HomeErrorCode.connectionLost:
        'A conversa caiu. Toque no microfone para começarmos de novo.',
    HomeErrorCode.network:
        'Sem internet agora. Assim que a conexão voltar, eu te aviso e a gente '
            'continua.',
    HomeErrorCode.microphone:
        'Não consegui usar o microfone. Toque em "Prefiro digitar" e me '
            'escreva.',
    HomeErrorCode.unknown:
        'Alguma coisa não funcionou aqui. Toque de novo que eu tento outra '
            'vez.',
  };

  /// Aviso de volta ao normal (AL-2). O banner vermelho sumir sozinho não basta:
  /// para quem não estava olhando a tela — ou não enxerga —, a recuperação
  /// precisa ser dita.
  static const String recovered = 'Pronto, estou te ouvindo de novo.';

  /// Frase de um código. É o único caminho para um texto de erro na tela.
  static String of(HomeErrorCode code) =>
      _messages[code] ?? _messages[HomeErrorCode.unknown]!;

  /// Todas as frases que a tela pode mostrar. Existe para o teste de varredura:
  /// mensagem de erro que não estiver aqui é literal solto — e reprova.
  static List<String> get all => _messages.values.toList(growable: false);

  /// Classifica a mensagem crua do SDK (sempre em inglês) num código.
  ///
  /// A ordem importa: a causa mais concreta ganha. "Could not start session:
  /// token expired" é problema de token, não de início — é o token que a
  /// próxima tentativa precisa renovar.
  static HomeErrorCode codeFor(
    String rawMessage, {
    HomeErrorCode fallback = HomeErrorCode.unknown,
  }) {
    final message = rawMessage.toLowerCase();
    bool has(String term) => message.contains(term);

    if (has('network') ||
        has('internet') ||
        has('offline') ||
        has('socketexception') ||
        has('host lookup') ||
        has('unreachable') ||
        has('timed out') ||
        has('timeout')) {
      return HomeErrorCode.network;
    }
    // `mic` inteiro, não pedaço: "dynamic" e "atomic" também contêm "mic".
    if (has('microphone') || RegExp(r'\bmic\b').hasMatch(message)) {
      return HomeErrorCode.microphone;
    }
    if (has('token') || has('unauthorized') || has('credential')) {
      return HomeErrorCode.tokenUnavailable;
    }
    if (has('start') || has('begin')) {
      return HomeErrorCode.startFailed;
    }
    if (has('send') || has('user message')) {
      return HomeErrorCode.sendFailed;
    }
    if (has('session') ||
        has('connect') ||
        has('websocket') ||
        has('livekit') ||
        has('closed')) {
      return HomeErrorCode.connectionLost;
    }
    return fallback;
  }

  /// Mensagem crua do SDK → frase da Maria.
  static String fromRaw(
    String rawMessage, {
    HomeErrorCode fallback = HomeErrorCode.unknown,
  }) =>
      of(codeFor(rawMessage, fallback: fallback));

  /// Falha de um `Result` → frase da Maria.
  ///
  /// O tipo do lado do erro varia entre camadas (`AppFailure` no repositório,
  /// `Exception` cru no datasource do token), então o que se classifica é o
  /// texto — e o `fallback` diz qual era a tentativa quando o texto não conta
  /// nada de útil.
  static String fromFailure(
    Object? failure, {
    HomeErrorCode fallback = HomeErrorCode.unknown,
  }) =>
      fromRaw('$failure', fallback: fallback);
}
