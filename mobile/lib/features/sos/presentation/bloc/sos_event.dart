part of 'sos_bloc.dart';

abstract class SosEvent extends Equatable {
  const SosEvent();

  @override
  List<Object?> get props => [];
}

/// A Maria pediu ajuda. Registra no servidor **imediatamente** — a contagem
/// que ela vê depois é só feedback.
class SosRequested extends SosEvent {
  const SosRequested({this.channel = EmergencyChannel.touch});

  final EmergencyChannel channel;

  @override
  List<Object?> get props => [channel];
}

/// Um segundo passou na contagem visual. **Não dispara nada**: quem dispara é
/// o servidor, e ele não depende deste aparelho (regra 2).
class SosCountdownTicked extends SosEvent {
  const SosCountdownTicked();
}

/// Hora de perguntar ao servidor como está o aviso. Não há push para a Maria:
/// é o polling que alimenta os quatro estados falados.
class SosStatusPolled extends SosEvent {
  const SosStatusPolled();
}

/// "Foi engano."
class SosCancelRequested extends SosEvent {
  const SosCancelRequested();
}

/// Quem a Maria quer chamar no telefone.
enum SosCallTarget {
  /// O contato principal da casa.
  contact,

  /// Emergência pública (192).
  emergencyService,
}

/// Abrir o discador. O app põe o número na tela; **quem liga é ela**.
class SosCallRequested extends SosEvent {
  const SosCallRequested(this.target);

  final SosCallTarget target;

  @override
  List<Object?> get props => [target];
}
