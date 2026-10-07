import 'package:equatable/equatable.dart';

import 'package:aura/features/medications/domain/entities/medication.dart';


/// Quem originou o evento, na língua da família.
enum ActivitySource {
  voice('por voz'),
  app('no app'),
  wearable('pelo relógio');

  const ActivitySource(this.label);
  final String label;
}

enum ActivityKind { dose, symptom, sos }

/// Uma linha da linha do tempo: o que aconteceu, quando e por onde.
class CareActivity extends Equatable {
  const CareActivity({
    required this.id,
    required this.kind,
    required this.title,
    required this.source,
    required this.occurredAt,
    this.concerning = false,
  });

  final String id;
  final ActivityKind kind;
  final String title;
  final ActivitySource source;
  final DateTime occurredAt;

  /// Pede atenção da família (sintoma, SOS, dose recusada).
  final bool concerning;

  @override
  List<Object?> get props => [id, kind, title, source, occurredAt, concerning];
}

enum DoseStatus {
  /// Todas as doses de hoje confirmadas.
  complete,

  /// Nada atrasado até agora.
  onTrack,

  /// Há dose cujo horário passou sem confirmação.
  late,

  /// Remédio sem horário fixo ("se necessário").
  asNeeded,
}

/// Situação de um remédio hoje.
class MedicationToday extends Equatable {
  const MedicationToday({
    required this.medication,
    required this.status,
    required this.takenCount,
    required this.dosesPerDay,
    this.nextTime,
    this.lastTakenAt,
    this.lastSource,
    this.declinedToday = false,
  });

  final Medication medication;
  final DoseStatus status;
  final int takenCount;
  final int dosesPerDay;

  /// Próximo horário ainda sem confirmação (`HH:mm`).
  final String? nextTime;
  final DateTime? lastTakenAt;
  final ActivitySource? lastSource;

  /// Hoje a Maria disse que NÃO tomou e não confirmou depois.
  final bool declinedToday;

  @override
  List<Object?> get props => [
        medication.id,
        status,
        takenCount,
        dosesPerDay,
        nextTime,
        lastTakenAt,
        lastSource,
        declinedToday,
      ];
}
