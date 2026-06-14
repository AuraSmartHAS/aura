import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';

import '../network/api_client.dart';
import '../notifications/notification_service.dart';
import '../session/auth_session.dart';
import '../session/token_store.dart';
import '../../features/auth/di/auth_module.dart';
import '../../features/carechain/di/carechain_module.dart';
import '../../features/caregiver_dashboard/di/dashboard_module.dart';
import '../../features/consent/di/consent_module.dart';
import '../../features/delivery_map/di/delivery_map_module.dart';
import '../../features/home/di/home_module.dart';
import '../../features/home_setup/di/home_setup_module.dart';
import '../../features/medications/di/medications_module.dart';
import '../../features/orders/di/orders_module.dart';
import '../../features/profile/di/profile_module.dart';
import '../../features/wearable/di/wearable_module.dart';
import '../../features/wellbeing360/di/wellbeing360_module.dart';

final sl = GetIt.instance;

/// Registers core infrastructure first, then each feature module.
void setupServiceLocator() {
  _setupCore();

  setupAuthModule(sl);
  setupConsentModule(sl);
  setupHomeModule(sl);
  setupHomeSetupModule(sl);
  setupWellbeing360Module(sl);
  setupCareChainModule(sl);
  setupOrdersModule(sl);
  setupDeliveryMapModule(sl);
  setupWearableModule(sl);
  setupMedicationsModule(sl);
  setupDashboardModule(sl);
  setupProfileModule(sl);
}

void _setupCore() {
  sl.registerLazySingleton<FlutterSecureStorage>(
    () => const FlutterSecureStorage(),
  );
  sl.registerLazySingleton<TokenStore>(() => TokenStore(sl()));
  sl.registerLazySingleton<AuthSession>(() => AuthSession(sl()));
  sl.registerLazySingleton<ApiClient>(
    () => ApiClient(tokenStore: sl(), session: sl()),
  );
  sl.registerLazySingleton<NotificationService>(
    () => NotificationService(apiClient: sl(), session: sl()),
  );
}
