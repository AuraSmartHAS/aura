part of 'map_bloc.dart';

abstract class MapEvent extends Equatable {
  const MapEvent();

  @override
  List<Object?> get props => [];
}

class LoadMapEvent extends MapEvent {
  const LoadMapEvent(this.orderId);

  final String orderId;

  @override
  List<Object?> get props => [orderId];
}
