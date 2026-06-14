import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../session/auth_session.dart';
import '../session/token_store.dart';
import 'auth_interceptor.dart';

/// Thin wrapper around [Dio] configured for the aura-server REST API.
///
/// All feature datasources depend on this single client so the Bearer token,
/// refresh logic and base URL are defined in exactly one place.
class ApiClient {
  ApiClient({
    required TokenStore tokenStore,
    required AuthSession session,
  }) : dio = Dio(
          BaseOptions(
            baseUrl: AppConfig.apiBaseUrl,
            connectTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 20),
            contentType: 'application/json',
          ),
        ) {
    dio.interceptors.add(
      AuthInterceptor(
        tokenStore: tokenStore,
        session: session,
        baseUrl: AppConfig.apiBaseUrl,
      ),
    );
    // Verbose HTTP logging (request + response bodies) in debug builds only,
    // so signup/login payloads and the returned `role` are visible in console.
    if (kDebugMode) {
      dio.interceptors.add(
        LogInterceptor(
          request: true,
          requestHeader: true,
          requestBody: true,
          responseHeader: false,
          responseBody: true,
          error: true,
          logPrint: (o) => debugPrint('[AURA-HTTP] $o'),
        ),
      );
    }
  }

  final Dio dio;
}
