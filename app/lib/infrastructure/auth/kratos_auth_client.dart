import 'package:dio/dio.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';

import '../config/kratos_config.dart';

/// Domain-shaped error so the UI can map an OIDC failure to a friendly
/// message without inspecting Dio internals.
class KratosAuthException implements Exception {
  final String message;
  const KratosAuthException(this.message);
  @override
  String toString() => 'KratosAuthException: $message';
}

/// KratosAuthClient runs the native-mobile OIDC dance:
///
///   1. POST /self-service/login/api with return_session_token_exchange_code
///      → Kratos returns a login flow whose `session_token_exchange_code`
///        carries the half-secret `init_code` the app keeps locally.
///   2. Open the OIDC provider's "auth" URL for the same flow in an
///      external browser via flutter_web_auth_2 (Google completes the
///      identity check there).
///   3. Kratos redirects back to our custom-scheme `return_to` deep
///      link with the matching `code` query parameter (the
///      `return_to_code`).
///   4. POST /sessions/token-exchange with both codes → Kratos issues a
///      session token the app stores in flutter_secure_storage and
///      attaches as X-Session-Token on every subsequent API request.
///
/// Phase 0 prerequisite: the Kratos OIDC provider config must have
/// `enable_session_token_exchange_code: true` for the Google provider,
/// and `return_to` must be on the whitelist
/// (`selfservice.allowed_return_urls`).
class KratosAuthClient {
  final Dio _dio;

  KratosAuthClient([Dio? dio])
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: KratosConfig.publicUrl,
              headers: {'Accept': 'application/json'},
            ));

  /// Runs the full native OIDC dance. Returns the Kratos session token
  /// on success. Throws KratosAuthException on cancellation or any
  /// upstream failure.
  Future<String> signInWithGoogle() async {
    final flow = await _initLoginFlow();
    final flowId = flow['id'] as String;
    final initCode = _extractInitCode(flow);

    final providerUrl = _buildProviderAuthUrl(flowId);

    final String callbackUri;
    try {
      callbackUri = await FlutterWebAuth2.authenticate(
        url: providerUrl,
        callbackUrlScheme: KratosConfig.callbackScheme,
      );
    } on Exception catch (e) {
      throw KratosAuthException('Browser sign-in was cancelled or failed: $e');
    }

    final returnToCode = Uri.parse(callbackUri).queryParameters['code'];
    if (returnToCode == null || returnToCode.isEmpty) {
      throw const KratosAuthException(
        'Kratos did not return a session_token_exchange code. '
        'Check that enable_session_token_exchange_code is true for the Google provider.',
      );
    }

    return _exchangeForSessionToken(initCode: initCode, returnToCode: returnToCode);
  }

  Future<Map<String, dynamic>> _initLoginFlow() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/self-service/login/api',
        queryParameters: {
          'return_session_token_exchange_code': 'true',
          'return_to': KratosConfig.returnTo,
        },
      );
      if (res.data == null) {
        throw const KratosAuthException('Empty response from Kratos login init.');
      }
      return res.data!;
    } on DioException catch (e) {
      throw KratosAuthException(
        'Kratos login init failed: ${e.response?.statusCode} ${e.response?.data}',
      );
    }
  }

  String _extractInitCode(Map<String, dynamic> flow) {
    final exchange = flow['session_token_exchange_code'];
    if (exchange is Map<String, dynamic>) {
      final code = exchange['init_code'];
      if (code is String && code.isNotEmpty) return code;
    }
    throw const KratosAuthException(
      'Login flow is missing session_token_exchange_code.init_code — '
      'the Kratos config probably has token exchange disabled.',
    );
  }

  /// Per the Kratos OIDC strategy: opening
  ///   {publicUrl}/self-service/methods/oidc/auth/{flow_id}?provider={id}
  /// kicks off the redirect to the IdP for an existing flow. Kratos
  /// honours the `return_to` we set at flow init when it redirects back.
  String _buildProviderAuthUrl(String flowId) {
    return Uri.parse('${KratosConfig.publicUrl}/self-service/methods/oidc/auth/$flowId')
        .replace(queryParameters: {'provider': KratosConfig.googleProviderId})
        .toString();
  }

  Future<String> _exchangeForSessionToken({
    required String initCode,
    required String returnToCode,
  }) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/sessions/token-exchange',
        queryParameters: {
          'init_code': initCode,
          'return_to_code': returnToCode,
        },
      );
      final body = res.data;
      if (body == null) {
        throw const KratosAuthException('Empty response from Kratos token exchange.');
      }
      final token = body['session_token'];
      if (token is String && token.isNotEmpty) return token;
      throw const KratosAuthException('Kratos token exchange returned no session_token.');
    } on DioException catch (e) {
      throw KratosAuthException(
        'Kratos token exchange failed: ${e.response?.statusCode} ${e.response?.data}',
      );
    }
  }
}
