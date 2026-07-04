import 'dart:async';

import 'package:dio/dio.dart';

import '../auth/session_storage.dart';

/// Header Kratos reads to identify a native-app caller's session. The
/// edge (Oathkeeper) introspects this against /sessions/whoami and
/// forwards the resolved X-User to the backend; our auth.Middleware in
/// Go reads X-User and stamps the home + user onto the request context.
const _sessionTokenHeader = 'X-Session-Token';

/// AuthInterceptor attaches the locally-stored Kratos session token to
/// every API request. On a 401 it clears the cached token (the session
/// has been revoked or expired) and signals the auth provider to drop
/// the user back to the login screen via [onUnauthenticated]. The
/// interceptor does NOT try to refresh on its own — Kratos session
/// tokens aren't refreshable; the user must re-do the OIDC dance.
class AuthInterceptor extends Interceptor {
  final SessionStorage _storage;
  final FutureOr<void> Function()? _onUnauthenticated;

  String? _cachedToken;

  AuthInterceptor({
    SessionStorage? storage,
    FutureOr<void> Function()? onUnauthenticated,
  })  : _storage = storage ?? SessionStorage(),
        _onUnauthenticated = onUnauthenticated;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    _cachedToken ??= await _storage.read();
    final token = _cachedToken;
    if (token != null && token.isNotEmpty) {
      options.headers[_sessionTokenHeader] = token;
    }
    handler.next(options);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401) {
      await _clearSession();
      if (_onUnauthenticated != null) {
        await _onUnauthenticated();
      }
    }
    handler.next(err);
  }

  Future<void> _clearSession() async {
    _cachedToken = null;
    await _storage.clear();
  }
}
