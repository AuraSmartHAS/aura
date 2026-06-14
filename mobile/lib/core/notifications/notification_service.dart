import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../network/api_client.dart';
import '../router/app_router.dart';
import '../router/app_routes.dart';
import '../session/auth_session.dart';

/// Background message handler (must be a top-level / static entry point).
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // No-op: deep links are handled when the app is opened from the notification.
}

/// Wires Firebase Cloud Messaging: permission, token registration with the
/// backend, and deep links (logistics push → `/orders/:id`).
class NotificationService {
  NotificationService({
    required ApiClient apiClient,
    required AuthSession session,
    FirebaseMessaging? messaging,
  })  : _apiClient = apiClient,
        _session = session,
        _messaging = messaging ?? FirebaseMessaging.instance;

  final ApiClient _apiClient;
  final AuthSession _session;
  final FirebaseMessaging _messaging;

  Future<void> init() async {
    try {
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      await _messaging.requestPermission();

      await registerToken();

      // Cold start from a notification tap.
      final initial = await _messaging.getInitialMessage();
      if (initial != null) _handleDeepLink(initial);

      FirebaseMessaging.onMessageOpenedApp.listen(_handleDeepLink);
    } catch (e) {
      debugPrint('NotificationService init failed: $e');
    }
  }

  /// Registers the device FCM token with the backend. Safe to call after login.
  Future<void> registerToken() async {
    if (!_session.isAuthenticated) return;
    try {
      final token = await _messaging.getToken();
      if (token == null) return;
      await _apiClient.dio.post(
        '/notifications/register-token',
        data: {'fcmToken': token},
      );
    } catch (e) {
      debugPrint('FCM token registration failed: $e');
    }
  }

  void _handleDeepLink(RemoteMessage message) {
    final orderId = message.data['orderId'];
    if (orderId is String && orderId.isNotEmpty) {
      AppRouter.router.go(AppRoutes.orderDetail(orderId));
    }
  }
}
