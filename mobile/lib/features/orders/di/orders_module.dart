import 'package:get_it/get_it.dart';
import '../../../core/network/api_client.dart';
import '../data/datasources/orders_remote_datasource.dart';
import '../data/repositories/orders_repository_impl.dart';
import '../domain/repositories/orders_repository.dart';
import '../domain/usecases/advance_order_usecase.dart';
import '../domain/usecases/get_home_orders_usecase.dart';
import '../domain/usecases/get_order_usecase.dart';
import '../presentation/bloc/order_tracking_bloc.dart';

void setupOrdersModule(GetIt sl) {
  sl.registerLazySingleton<OrdersRemoteDataSource>(
    () => OrdersRemoteDataSourceImpl(sl<ApiClient>()),
  );

  sl.registerLazySingleton<OrdersRepository>(
    () => OrdersRepositoryImpl(sl<OrdersRemoteDataSource>()),
  );

  sl.registerFactory<GetOrderUseCase>(
    () => GetOrderUseCase(sl<OrdersRepository>()),
  );
  sl.registerFactory<GetHomeOrdersUseCase>(
    () => GetHomeOrdersUseCase(sl<OrdersRepository>()),
  );
  sl.registerFactory<AdvanceOrderUseCase>(
    () => AdvanceOrderUseCase(sl<OrdersRepository>()),
  );

  sl.registerFactory<OrderTrackingBloc>(
    () => OrderTrackingBloc(
      getOrderUseCase: sl<GetOrderUseCase>(),
      advanceOrderUseCase: sl<AdvanceOrderUseCase>(),
    ),
  );
}
