part of 'consent_bloc.dart';

abstract class ConsentEvent extends Equatable {
  const ConsentEvent();

  @override
  List<Object?> get props => [];
}

class AcceptConsentEvent extends ConsentEvent {
  const AcceptConsentEvent();
}
