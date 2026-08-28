import '../../domain/entities/emergency.dart';

/// JSON do contrato → entidades do SOS.
///
/// Regra que vale para todo este arquivo: **campo ausente nunca vira promessa.**
/// `canPromiseAlert` sem valor é `false`; `transportReal` sem valor é `false`;
/// `simulated` sem valor é `true`. Um servidor antigo, um proxy que corta campo
/// ou um erro de digitação no JSON degradam a tela para a ligação — não para o
/// anúncio de que a Ana foi avisada.
class EmergencyMapper {
  const EmergencyMapper._();

  static EmergencyTicket ticketFromJson(Map<String, dynamic> json) {
    return EmergencyTicket(
      id: _string(json['emergencyId']) ?? '',
      state: EmergencyState.fromWire(_string(json['state'])),
      dispatchAt: _dateTime(json['dispatchAt']),
      cancelWindowSeconds: _int(json['cancelWindowSeconds']) ?? 5,
      escalateAfterSeconds: _int(json['escalateAfterSeconds']),
      transportReal: _bool(json['transportReal']) ?? false,
      simulated: _bool(json['simulated']) ?? true,
      recipientCount: _int(json['recipientCount']) ?? 0,
      primaryContactName: _string(json['primaryContactName']),
      throttled: _bool(json['throttled']) ?? false,
      deduplicated: _bool(json['deduplicated']) ?? false,
      canPromiseAlert: _bool(json['canPromiseAlert']) ?? false,
      degradedReason: DegradedReason.fromWire(_string(json['degradedReason'])),
      spokenMessage: _string(json['spokenMessage']),
    );
  }

  static EmergencyStatus statusFromJson(Map<String, dynamic> json) {
    return EmergencyStatus(
      id: _string(json['emergencyId']) ?? '',
      state: EmergencyState.fromWire(_string(json['state'])),
      dispatchedAt: _dateTime(json['dispatchedAt']),
      acknowledgedAt: _dateTime(json['acknowledgedAt']),
      acknowledgedByName: _string(json['acknowledgedByName']),
      escalated: _bool(json['escalated']) ?? false,
      notifiedCount: _int(json['notifiedCount']) ?? 0,
      transportReal: _bool(json['transportReal']) ?? false,
      simulated: _bool(json['simulated']) ?? true,
      canPromiseAlert: _bool(json['canPromiseAlert']) ?? false,
      degradedReason: DegradedReason.fromWire(_string(json['degradedReason'])),
      spokenMessage: _string(json['spokenMessage']),
    );
  }

  static EmergencyCancellation cancellationFromJson(Map<String, dynamic> json) {
    return EmergencyCancellation(
      id: _string(json['emergencyId']) ?? '',
      state: EmergencyState.fromWire(_string(json['state'])),
      withinWindow: _bool(json['withinWindow']) ?? false,
      // Cancelar sem saber se o aviso saiu: assume-se que saiu. A frase "não
      // avisei ninguém" é a única que dói se estiver errada.
      alertSent: _bool(json['alertSent']) ?? true,
      retractionSent: _bool(json['retractionSent']) ?? false,
      simulated: _bool(json['simulated']) ?? true,
      spokenMessage: _string(json['spokenMessage']),
    );
  }

  static String? _string(Object? value) {
    if (value is String && value.trim().isNotEmpty) return value.trim();
    return null;
  }

  static bool? _bool(Object? value) => value is bool ? value : null;

  static int? _int(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static DateTime? _dateTime(Object? value) {
    final text = _string(value);
    if (text == null) return null;
    // A hora é mostrada para a Maria ("o aviso chegou às 14h32"), então precisa
    // ser a hora do relógio dela.
    return DateTime.tryParse(text)?.toLocal();
  }
}
