import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:aura/core/errors/failure_messages.dart';
import 'package:aura/core/errors/result.dart';
import '../../domain/entities/order_detail.dart';
import '../../domain/usecases/advance_order_usecase.dart';
import '../../domain/usecases/get_order_usecase.dart';

part 'order_tracking_event.dart';
part 'order_tracking_state.dart';

class OrderTrackingBloc extends Bloc<OrderTrackingEvent, OrderTrackingState> {
  OrderTrackingBloc({
    required GetOrderUseCase getOrderUseCase,
    required AdvanceOrderUseCase advanceOrderUseCase,
  })  : _getOrderUseCase = getOrderUseCase,
        _advanceOrderUseCase = advanceOrderUseCase,
        super(const OrderTrackingState.loading()) {
    on<LoadOrderEvent>(_onLoad);
    on<AdvanceOrderEvent>(_onAdvance);
  }

  final GetOrderUseCase _getOrderUseCase;
  final AdvanceOrderUseCase _advanceOrderUseCase;

  Future<void> _onLoad(
    LoadOrderEvent event,
    Emitter<OrderTrackingState> emit,
  ) async {
    emit(const OrderTrackingState.loading());
    final result = await _getOrderUseCase(event.orderId);
    switch (result) {
      case Success(:final data):
        emit(OrderTrackingState.ready(data));
      case Failure(:final failure):
        emit(OrderTrackingState.error(AppFailureMessage.resolve(failure)));
    }
  }

  Future<void> _onAdvance(
    AdvanceOrderEvent event,
    Emitter<OrderTrackingState> emit,
  ) async {
    emit(state.copyWith(isAdvancing: true));
    final result = await _advanceOrderUseCase(event.orderId);
    switch (result) {
      case Success(:final data):
        emit(OrderTrackingState.ready(data));
      case Failure(:final failure):
        emit(state.copyWith(
          isAdvancing: false,
          errorMessage: AppFailureMessage.resolve(failure),
        ));
    }
  }
}
