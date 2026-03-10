import 'dart:convert';
import 'dart:developer' as developer;

import 'package:dio/dio.dart';
import '../config/oauth_config.dart';

/// Dio interceptor that obtains and attaches a JWT bearer token
/// via the OAuth2 client_credentials grant.
class AuthInterceptor extends Interceptor {
  String? _accessToken;
  DateTime? _expiresAt;

  // Separate Dio instance for token requests to avoid interceptor recursion.
  final Dio _tokenDio = Dio();

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      final token = await _getToken();
      options.headers['Authorization'] = 'Bearer $token';
      handler.next(options);
    } catch (e) {
      handler.reject(
        DioException(requestOptions: options, error: e),
      );
    }
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    // If we get a 401, the token may have been revoked — clear and retry once.
    if (err.response?.statusCode == 401 && _accessToken != null) {
      _accessToken = null;
      _expiresAt = null;

      try {
        final token = await _getToken();
        final opts = err.requestOptions;
        opts.headers['Authorization'] = 'Bearer $token';

        final response = await _tokenDio.fetch(opts);
        return handler.resolve(response);
      } catch (_) {
        // Retry failed — propagate the original error.
      }
    }
    handler.next(err);
  }

  Future<String> _getToken() async {
    // Return cached token if still valid (with 30s buffer).
    if (_accessToken != null &&
        _expiresAt != null &&
        _expiresAt!.isAfter(DateTime.now().add(const Duration(seconds: 30)))) {
      return _accessToken!;
    }

    final credentials = base64Encode(
      utf8.encode('${OAuthConfig.clientId}:${OAuthConfig.clientSecret}'),
    );

    developer.log(
      'Requesting token from ${OAuthConfig.tokenUrl} '
      'client=${OAuthConfig.clientId} scope=${OAuthConfig.scope}',
      name: 'AuthInterceptor',
    );

    try {
      final response = await _tokenDio.post(
        OAuthConfig.tokenUrl,
        data: 'grant_type=client_credentials&scope=${OAuthConfig.scope}',
        options: Options(
          headers: {
            'Authorization': 'Basic $credentials',
            'Content-Type': 'application/x-www-form-urlencoded',
          },
        ),
      );

      final body = response.data as Map<String, dynamic>;
      _accessToken = body['access_token'] as String;
      final expiresIn = body['expires_in'] as int;
      _expiresAt = DateTime.now().add(Duration(seconds: expiresIn));

      developer.log('Token obtained, expires in ${expiresIn}s', name: 'AuthInterceptor');
      return _accessToken!;
    } on DioException catch (e) {
      developer.log(
        'Token request failed: ${e.response?.statusCode} ${e.response?.data}',
        name: 'AuthInterceptor',
        level: 1000,
      );
      rethrow;
    }
  }
}
