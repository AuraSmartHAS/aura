part of 'sos_bloc.dart';

/// O que a tela do SOS está mostrando.
///
/// Quatro destes são **os quatro estados falados** da regra 4, e todos vêm do
/// estado do servidor: [registering] e [counting] são "enviando", [delivered] é
/// "entregue", [acknowledged] é "confirmado pela cuidadora" e [failed] é
/// "falha". [cancelled] é o quinto caminho, o do "foi engano".
enum SosPhase {
  /// Ninguém pediu nada ainda.
  idle,

  /// O toque está indo para o servidor.
  registering,

  /// Registrado. A contagem visual corre; o disparo é do servidor.
  counting,

  /// O servidor disparou o aviso.
  delivered,

  /// A cuidadora confirmou.
  acknowledged,

  /// A Maria cancelou.
  cancelled,

  /// Não deu para avisar ninguém pelo aplicativo — inclusive quando o servidor
  /// respondeu bem, mas com `canPromiseAlert: false`. Se o aviso não pode ser
  /// prometido, **não houve aviso**, e o que resta é a ligação.
  failed,
}

class SosState extends Equatable {
  const SosState({
    this.phase = SosPhase.idle,
    this.emergencyId,
    this.spokenMessage,
    this.errorMessage,
    this.secondsRemaining = 0,
    this.cancelWindowSeconds = 5,
    this.contactName,
    this.canPromiseAlert = false,
    this.degradedReason,
    this.dispatchedAt,
    this.deduplicated = false,
    this.isCancelling = false,
    this.cancelWithinWindow = false,
    this.alertSent = false,
    this.retractionSent = false,
    this.dialerFailed = false,
    this.contactPhoneKnown = false,
    this.emergencyPhone = '192',
  });

  final SosPhase phase;
  final String? emergencyId;

  /// A frase que a tela mostra e anuncia. Vem do `spokenMessage` do servidor
  /// sempre que ele existe; a cópia local é só a rede de segurança.
  final String? spokenMessage;

  /// Frase do dicionário de erros quando o pedido **não chegou** ao servidor.
  /// Diferente de [degradedReason], que é o servidor respondendo que não pode
  /// prometer o aviso.
  final String? errorMessage;

  /// Contagem visual. Não governa disparo nenhum.
  final int secondsRemaining;
  final int cancelWindowSeconds;

  /// Primeiro nome do contato principal, para as falas.
  final String? contactName;

  /// **A única pergunta antes de prometer "avisei a Ana".**
  final bool canPromiseAlert;
  final DegradedReason? degradedReason;
  final DateTime? dispatchedAt;

  /// O servidor devolveu a emergência que já estava aberta.
  final bool deduplicated;

  final bool isCancelling;
  final bool cancelWithinWindow;
  final bool alertSent;
  final bool retractionSent;

  /// O discador não abriu (aparelho sem telefone, número não configurado).
  final bool dialerFailed;

  /// Existe telefone do contato guardado neste aparelho.
  final bool contactPhoneKnown;

  /// Emergência pública mostrada no botão de um toque. Vem da configuração e
  /// atravessa o estado para que nenhum widget precise ler o ambiente.
  final String emergencyPhone;

  /// O pedido está no ar e ainda pode ser retirado — dentro da janela ou
  /// depois dela, quando a retração ainda vale a pena.
  bool get canCancel =>
      emergencyId != null &&
      (phase == SosPhase.counting || phase == SosPhase.delivered);

  /// A tela caiu para o caminho de ligação: ou o servidor não pôde prometer o
  /// aviso, ou o pedido nem chegou nele.
  bool get offersCallInstead => phase == SosPhase.failed;

  /// Já existe pedido em andamento — o toque seguinte não abre outro.
  bool get isBusy => phase != SosPhase.idle;

  SosState copyWith({
    SosPhase? phase,
    String? emergencyId,
    String? spokenMessage,
    String? errorMessage,
    bool clearError = false,
    int? secondsRemaining,
    int? cancelWindowSeconds,
    String? contactName,
    bool? canPromiseAlert,
    DegradedReason? degradedReason,
    bool clearDegradedReason = false,
    DateTime? dispatchedAt,
    bool? deduplicated,
    bool? isCancelling,
    bool? cancelWithinWindow,
    bool? alertSent,
    bool? retractionSent,
    bool? dialerFailed,
    bool? contactPhoneKnown,
    String? emergencyPhone,
  }) {
    return SosState(
      phase: phase ?? this.phase,
      emergencyId: emergencyId ?? this.emergencyId,
      spokenMessage: spokenMessage ?? this.spokenMessage,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      secondsRemaining: secondsRemaining ?? this.secondsRemaining,
      cancelWindowSeconds: cancelWindowSeconds ?? this.cancelWindowSeconds,
      contactName: contactName ?? this.contactName,
      canPromiseAlert: canPromiseAlert ?? this.canPromiseAlert,
      degradedReason: clearDegradedReason
          ? null
          : (degradedReason ?? this.degradedReason),
      dispatchedAt: dispatchedAt ?? this.dispatchedAt,
      deduplicated: deduplicated ?? this.deduplicated,
      isCancelling: isCancelling ?? this.isCancelling,
      cancelWithinWindow: cancelWithinWindow ?? this.cancelWithinWindow,
      alertSent: alertSent ?? this.alertSent,
      retractionSent: retractionSent ?? this.retractionSent,
      dialerFailed: dialerFailed ?? this.dialerFailed,
      contactPhoneKnown: contactPhoneKnown ?? this.contactPhoneKnown,
      emergencyPhone: emergencyPhone ?? this.emergencyPhone,
    );
  }

  @override
  List<Object?> get props => [
        phase,
        emergencyId,
        spokenMessage,
        errorMessage,
        secondsRemaining,
        cancelWindowSeconds,
        contactName,
        canPromiseAlert,
        degradedReason,
        dispatchedAt,
        deduplicated,
        isCancelling,
        cancelWithinWindow,
        alertSent,
        retractionSent,
        dialerFailed,
        contactPhoneKnown,
        emergencyPhone,
      ];
}
