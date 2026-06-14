part of 'wearable_bloc.dart';

enum WearableStatus { initial, loading, ready, error }

class WearableState extends Equatable {
  const WearableState({required this.status, this.vitals, this.errorMessage});

  const WearableState.initial()
      : status = WearableStatus.initial,
        vitals = null,
        errorMessage = null;

  const WearableState.loading()
      : status = WearableStatus.loading,
        vitals = null,
        errorMessage = null;

  const WearableState.ready(this.vitals)
      : status = WearableStatus.ready,
        errorMessage = null;

  const WearableState.error(this.errorMessage)
      : status = WearableStatus.error,
        vitals = null;

  final WearableStatus status;
  final Vitals? vitals;
  final String? errorMessage;

  @override
  List<Object?> get props => [status, vitals?.steps, vitals?.restingHeartRate, errorMessage];
}
