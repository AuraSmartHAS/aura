part of 'consent_bloc.dart';

abstract class ConsentState extends Equatable {
  const ConsentState();

  @override
  List<Object?> get props => [];
}

class ConsentInitial extends ConsentState {
  const ConsentInitial();
}

class ConsentLoading extends ConsentState {
  const ConsentLoading();
}

class ConsentAccepted extends ConsentState {
  const ConsentAccepted();
}

class ConsentError extends ConsentState {
  const ConsentError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
