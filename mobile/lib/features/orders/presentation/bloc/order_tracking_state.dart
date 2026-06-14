part of 'order_tracking_bloc.dart';

enum OrderTrackingStatus { loading, ready, error }

class OrderTrackingState extends Equatable {
  const OrderTrackingState({
    required this.status,
    this.order,
    this.isAdvancing = false,
    this.errorMessage,
  });

  const OrderTrackingState.loading()
      : status = OrderTrackingStatus.loading,
        order = null,
        isAdvancing = false,
        errorMessage = null;

  const OrderTrackingState.ready(this.order)
      : status = OrderTrackingStatus.ready,
        isAdvancing = false,
        errorMessage = null;

  const OrderTrackingState.error(this.errorMessage)
      : status = OrderTrackingStatus.error,
        order = null,
        isAdvancing = false;

  final OrderTrackingStatus status;
  final OrderDetail? order;
  final bool isAdvancing;
  final String? errorMessage;

  OrderTrackingState copyWith({bool? isAdvancing, String? errorMessage}) {
    return OrderTrackingState(
      status: status,
      order: order,
      isAdvancing: isAdvancing ?? this.isAdvancing,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, order?.orderId, order?.stage, isAdvancing, errorMessage];
}
