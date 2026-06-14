part of 'home_setup_bloc.dart';

enum SetupStep { form, checklist, done }

class HomeSetupState extends Equatable {
  const HomeSetupState({
    required this.step,
    required this.isLoading,
    required this.checklist,
    this.home,
    this.errorMessage,
  });

  factory HomeSetupState.initial() => HomeSetupState(
        step: SetupStep.form,
        isLoading: false,
        checklist: {for (final k in SafetyChecklistKeys.all) k: false},
      );

  final SetupStep step;
  final bool isLoading;
  final Map<String, bool> checklist;
  final Home? home;
  final String? errorMessage;

  HomeSetupState copyWith({
    SetupStep? step,
    bool? isLoading,
    Map<String, bool>? checklist,
    Home? home,
    String? errorMessage,
    bool clearError = false,
  }) {
    return HomeSetupState(
      step: step ?? this.step,
      isLoading: isLoading ?? this.isLoading,
      checklist: checklist ?? this.checklist,
      home: home ?? this.home,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [step, isLoading, checklist, home?.id, errorMessage];
}
