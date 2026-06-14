import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:aura/core/errors/failure_messages.dart';
import 'package:aura/core/errors/result.dart';
import 'package:aura/features/orders/domain/entities/order_detail.dart';
import 'package:aura/features/orders/domain/usecases/get_order_usecase.dart';

part 'map_event.dart';
part 'map_state.dart';

class MapBloc extends Bloc<MapEvent, MapState> {
  MapBloc(this._getOrderUseCase) : super(const MapState.loading()) {
    on<LoadMapEvent>(_onLoad);
  }

  final GetOrderUseCase _getOrderUseCase;

  Future<void> _onLoad(LoadMapEvent event, Emitter<MapState> emit) async {
    emit(const MapState.loading());

    // Request location access without breaking if it is denied (UI-06).
    final hasLocation = await _ensureLocationPermission();

    final result = await _getOrderUseCase(event.orderId);
    switch (result) {
      case Success(:final data):
        emit(MapState.ready(order: data, hasLocation: hasLocation));
      case Failure(:final failure):
        emit(MapState.error(AppFailureMessage.resolve(failure)));
    }
  }

  Future<bool> _ensureLocationPermission() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return false;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      return permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;
    } catch (_) {
      return false;
    }
  }
}
