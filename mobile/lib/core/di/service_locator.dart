import 'package:get_it/get_it.dart';
import '../../features/auth/di/auth_module.dart';
import '../../features/home/di/home_module.dart';
import '../../features/profile/di/profile_module.dart';

final sl = GetIt.instance;

void setupServiceLocator() {
  _setupAuthModule();
  _setupHomeModule();
  _setupProfileModule();
}

void _setupAuthModule() {
  setupAuthModule(sl);
}

void _setupHomeModule() {
  setupHomeModule(sl);
}

void _setupProfileModule() {
  setupProfileModule(sl);
}
