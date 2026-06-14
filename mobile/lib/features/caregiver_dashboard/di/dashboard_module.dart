import 'package:get_it/get_it.dart';
import '../../../core/session/auth_session.dart';
import '../../home_setup/domain/usecases/get_home_usecase.dart';
import '../../wellbeing360/domain/usecases/get_scores_usecase.dart';
import '../presentation/bloc/dashboard_bloc.dart';

void setupDashboardModule(GetIt sl) {
  // Reuses use cases registered by home_setup and wellbeing360 modules.
  sl.registerFactory<DashboardBloc>(
    () => DashboardBloc(
      getHomeUseCase: sl<GetHomeUseCase>(),
      getScoresUseCase: sl<GetScoresUseCase>(),
      session: sl<AuthSession>(),
    ),
  );
}
