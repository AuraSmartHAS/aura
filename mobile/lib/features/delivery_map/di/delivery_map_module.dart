import 'package:get_it/get_it.dart';
import '../../orders/domain/usecases/get_order_usecase.dart';
import '../presentation/bloc/map_bloc.dart';

void setupDeliveryMapModule(GetIt sl) {
  // Reuses GetOrderUseCase registered by the orders module.
  sl.registerFactory<MapBloc>(() => MapBloc(sl<GetOrderUseCase>()));
}
