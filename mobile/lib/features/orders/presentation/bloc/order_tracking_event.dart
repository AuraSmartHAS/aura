part of 'order_tracking_bloc.dart';

abstract class OrderTrackingEvent extends Equatable {
  const OrderTrackingEvent();

  @override
  List<Object?> get props => [];
}

class LoadOrderEvent extends OrderTrackingEvent {
  const LoadOrderEvent(this.orderId);

  final String orderId;

  @override
  List<Object?> get props => [orderId];
}

class AdvanceOrderEvent extends OrderTrackingEvent {
  const AdvanceOrderEvent(this.orderId);

  final String orderId;

  @override
  List<Object?> get props => [orderId];
}
