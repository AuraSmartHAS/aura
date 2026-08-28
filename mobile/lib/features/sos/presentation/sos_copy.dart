import '../domain/entities/emergency.dart';

/// Tudo o que a tela do SOS diz, num lugar só (correção C3).
///
/// Três regras governam cada frase daqui:
///
/// 1. **O servidor tem a palavra final.** Quando a resposta trouxer
///    `spokenMessage`, é ela que vai para a tela — o que está aqui é a rede de
///    segurança para quando o campo vier vazio, e nunca promete mais que ele.
/// 2. **Nada de pretérito sobre evento não confirmado.** "Avisei a Ana" só
///    aparece quando o servidor disse que disparou; enquanto isso é "estou
///    avisando".
/// 3. **O AURA não é central de emergência.** Nenhuma frase diz "ajuda a
///    caminho", "central 24h" ou "socorro chamado". O que o produto faz é
///    avisar uma pessoa, e é isso que a cópia diz.
class SosCopy {
  const SosCopy._();

  // ── O botão de 64dp ──────────────────────────────────────────────

  static const String buttonLabel = 'SOS';
  static const String buttonSemantics = 'Pedir ajuda agora';

  // ── A folha de acompanhamento ────────────────────────────────────

  static const String panelTitle = 'Pedido de ajuda';

  /// Fica visível em todos os estados. É o guardrail do produto escrito na
  /// tela, não só no documento.
  static const String scopeDisclaimer =
      'O AURA avisa uma pessoa da sua confiança. Não somos central de '
      'emergência e não temos plantão.';

  /// Por que a contagem não é o disparo (regra 2). A Maria não precisa entender
  /// arquitetura, precisa saber que pode soltar o telefone.
  static const String dispatchIsServerSide =
      'Quem manda o aviso é o AURA, não este aparelho. Pode deixar o celular de '
      'lado: o aviso sai de qualquer jeito.';

  static const String cancelWhileCounting = 'Foi engano — cancelar';
  static const String cancelAfterDispatch = 'Foi engano — avisar que estou bem';
  static const String cancelSemantics = 'Cancelar o pedido de ajuda';
  static const String close = 'Fechar';

  static String countdown(int seconds) => seconds <= 0
      ? 'O aviso está saindo agora.'
      : 'O aviso sai em $seconds ${seconds == 1 ? 'segundo' : 'segundos'}.';

  // ── Ligações ─────────────────────────────────────────────────────

  static String callContact(String? contactName) => contactName == null
      ? 'Ligar para quem cuida de você'
      : 'Ligar para a $contactName';

  static String callEmergency(String phone) => 'Ligar $phone';

  static const String callEmergencySubtitle =
      'Abre o telefone com o número pronto. Quem aperta para ligar é você.';

  static const String callNotOpened =
      'Não consegui abrir o telefone deste aparelho. Se puder, peça para '
      'alguém ligar.';

  static const String noContactPhone =
      'Não tenho o telefone de quem cuida de você guardado aqui.';

  /// Aparelho novo, sem casa conhecida: não há a quem avisar, e dizer o
  /// contrário seria a pior mentira possível.
  static const String noPairedHome =
      'Este aparelho ainda não sabe de qual casa você é, então não tenho a quem '
      'avisar. Toque no botão grande para ligar.';

  // ── Os quatro estados falados (regra 4) ──────────────────────────
  //
  // Rede de segurança: o servidor manda a frase pronta em `spokenMessage` e é
  // ela que a tela usa. Estas entram quando o campo vem vazio.

  /// 1/4 — enviando.
  static String sending(String? contactName) => contactName == null
      ? 'Estou pedindo ajuda para você agora.'
      : 'Estou avisando a $contactName.';

  /// 2/4 — entregue, com a hora. "Saiu" e não "chegou": o servidor confirma o
  /// disparo, não a leitura.
  static String delivered(String? contactName, DateTime? at) {
    final quem = contactName == null ? 'quem cuida de você' : 'a $contactName';
    final quando = at == null ? '' : ' às ${clockTime(at)}';
    return 'Pronto. O aviso saiu para $quem$quando. Fico aqui com você.';
  }

  /// 3/4 — confirmado pela cuidadora.
  static String acknowledged(String? contactName) => contactName == null
      ? 'Quem cuida de você viu o aviso e disse que está indo.'
      : 'A $contactName viu e disse que está indo.';

  /// 4/4 — falha. É também o estado de `canPromiseAlert: false`: se o aviso não
  /// pode ser prometido, não houve aviso.
  static String failed(String? contactName) => contactName == null
      ? 'Não consegui avisar ninguém daqui. Toque no botão grande para ligar.'
      : 'Não consegui avisar a $contactName. Toque no botão grande para ligar '
          'para ela.';

  // ── Degradação (regra 1) ─────────────────────────────────────────

  /// O texto do botão quando o servidor diz que não pode prometer o aviso.
  static String cannotAlertAction(String? contactName) => contactName == null
      ? 'Não consigo avisar daqui — toque para ligar'
      : 'Não consigo avisar a $contactName daqui — toque para ligar para ela';

  /// O motivo, em uma frase. Os três levam à ligação, mas a Maria merece saber
  /// qual deles é.
  static String degradedReason(DegradedReason reason, String? contactName) {
    final quem = contactName == null ? 'quem cuida de você' : 'a $contactName';
    switch (reason) {
      case DegradedReason.simulatedTransport:
        return 'Este aviso ainda não consegue sair para o celular de $quem. A '
            'ligação funciona.';
      case DegradedReason.noRegisteredDevice:
        return 'O celular de $quem não está preparado para receber o meu '
            'aviso. A ligação funciona.';
      case DegradedReason.throttled:
        return 'Você pediu ajuda várias vezes seguidas. Para não confundir '
            '$quem com avisos repetidos, este não vai sair — ligue para ela.';
      case DegradedReason.unknown:
        return 'Não consigo mandar o aviso pelo aplicativo agora. A ligação '
            'funciona.';
    }
  }

  // ── Cancelamento ─────────────────────────────────────────────────

  static String cancelled({
    required bool withinWindow,
    required bool alertSent,
    String? contactName,
  }) {
    final quem = contactName == null ? 'quem cuida de você' : 'a $contactName';
    if (withinWindow && !alertSent) {
      return 'Cancelado. O aviso não saiu, e eu contei para $quem que foi '
          'engano.';
    }
    return 'O aviso já tinha saído. Contei para $quem que foi engano — ela '
        'pode ligar para confirmar.';
  }

  /// Toque repetido dentro da mesma emergência: o servidor deduplica, e a tela
  /// diz por que não abriu um segundo pedido.
  static const String deduplicated =
      'Seu pedido de ajuda já está em andamento — não precisa pedir de novo.';

  // ── Utilidades ───────────────────────────────────────────────────

  /// Hora no formato que a Maria lê ("14h32").
  static String clockTime(DateTime at) =>
      '${at.hour}h${at.minute.toString().padLeft(2, '0')}';
}
