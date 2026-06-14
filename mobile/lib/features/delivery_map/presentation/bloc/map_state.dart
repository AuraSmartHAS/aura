part of 'map_bloc.dart';

enum MapStatus { loading, ready, error }

class MapState extends Equatable {
  const MapState({
    required this.status,
    this.order,
    this.hasLocation = false,
    this.errorMessage,
  });

  const MapState.loading()
      : status = MapStatus.loading,
        order = null,
        hasLocation = false,
        errorMessage = null;

  const MapState.ready({required this.order, required this.hasLocation})
      : status = MapStatus.ready,
        errorMessage = null;

  const MapState.error(this.errorMessage)
      : status = MapStatus.error,
        order = null,
        hasLocation = false;

  final MapStatus status;
  final OrderDetail? order;
  final bool hasLocation;
  final String? errorMessage;

  @override
  List<Object?> get props => [status, order?.orderId, hasLocation, errorMessage];
}
