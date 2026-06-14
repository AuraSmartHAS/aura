part of 'home_setup_bloc.dart';

abstract class HomeSetupEvent extends Equatable {
  const HomeSetupEvent();

  @override
  List<Object?> get props => [];
}

class SubmitHomeFormEvent extends HomeSetupEvent {
  const SubmitHomeFormEvent({
    required this.patientName,
    required this.cep,
    this.birthDate,
    this.label,
  });

  final String patientName;
  final String cep;
  final String? birthDate;
  final String? label;

  @override
  List<Object?> get props => [patientName, cep, birthDate, label];
}

class ToggleChecklistItemEvent extends HomeSetupEvent {
  const ToggleChecklistItemEvent(this.key, this.value);

  final String key;
  final bool value;

  @override
  List<Object?> get props => [key, value];
}

class SubmitChecklistEvent extends HomeSetupEvent {
  const SubmitChecklistEvent();
}
