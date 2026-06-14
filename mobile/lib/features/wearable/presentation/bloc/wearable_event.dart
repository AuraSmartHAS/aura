part of 'wearable_bloc.dart';

abstract class WearableEvent extends Equatable {
  const WearableEvent();

  @override
  List<Object?> get props => [];
}

class ConnectWearableEvent extends WearableEvent {
  const ConnectWearableEvent();
}
