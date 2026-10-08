import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'core/config/app_config.dart';
import 'core/di/service_locator.dart';
import 'core/notifications/notification_service.dart';
import 'core/router/app_router.dart';
import 'core/session/auth_session.dart';
import 'core/theme/app_theme.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await AppConfig.load();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Antes do runApp: é o ponto de entrada do isolate de segundo plano.
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  setupServiceLocator();

  // Hydrate the in-memory session from secure storage before building routes.
  await sl<AuthSession>().bootstrap();

  // Best-effort FCM setup: canais, permissão, token e deep links.
  unawaited(sl<NotificationService>().init());

  runApp(const AuraApp());
}

class AuraApp extends StatelessWidget {
  const AuraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'AURA',
      theme: AppTheme.lightTheme,
      routerConfig: AppRouter.router,
      debugShowCheckedModeBanner: false,
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [
        Locale('pt', 'BR'),
        Locale('pt'),
        Locale('en'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // Honor the user's OS text-size choice (accessibility) but clamp so the
      // large fixed type scale never blows out layouts for the elderly audience.
      builder: (context, child) => MediaQuery.withClampedTextScaling(
        minScaleFactor: 1.0,
        maxScaleFactor: 1.3,
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}
