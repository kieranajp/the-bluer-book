import 'dart:async';

import 'package:dio/dio.dart';

import '../auth/session_storage.dart';
import '../config/api_config.dart';
import 'auth_interceptor.dart';

class ApiClient {
  late final Dio _dio;

  /// [onUnauthenticated] is called by the AuthInterceptor when the
  /// backend rejects a request with 401 — typically because the Kratos
  /// session has expired or been revoked. The auth provider wires this
  /// up to drop the user back to the login screen.
  ApiClient({
    SessionStorage? sessionStorage,
    FutureOr<void> Function()? onUnauthenticated,
  }) {
    _dio = Dio(
      BaseOptions(
        baseUrl: '${ApiConfig.baseUrl}/api',
        connectTimeout: ApiConfig.timeout,
        receiveTimeout: ApiConfig.timeout,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    // Auth interceptor goes first so the token is attached before logging.
    _dio.interceptors.add(AuthInterceptor(
      storage: sessionStorage,
      onUnauthenticated: onUnauthenticated,
    ));

    _dio.interceptors.add(
      LogInterceptor(
        requestBody: false,
        responseBody: true,
        requestHeader: true,
        responseHeader: true,
        error: true,
        request: true,
      ),
    );
  }

  Dio get dio => _dio;
}
