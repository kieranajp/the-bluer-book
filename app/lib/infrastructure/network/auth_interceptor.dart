import 'dart:async';
import 'dart:developer' as developer;

import 'package:dio/dio.dart';

import '../auth/auth_repository.dart';
import '../auth/token_store.dart';

/// What a refresh attempt settled. [session] is null when it produced no new
/// token; [sessionDead] then says whether the grant was rejected — only then is
/// signing the person out the right answer.
typedef _RefreshResult = ({AuthSession? session, bool sessionDead});

/// Attaches the signed-in person's bearer token to every API call and keeps it
/// fresh.
///
/// A request made within [_refreshWindow] of expiry refreshes first; a 401
/// refreshes once and replays. Only a grant the server rejects ends the
/// session — a refresh that could not be delivered leaves the tokens alone, so
/// a spell without a network costs a request rather than the login.
class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    TokenStore? store,
    AuthRepository? auth,
    FutureOr<void> Function()? onSignedOut,
    Dio? retryClient,
  })  : _store = store ?? TokenStore(),
        _auth = auth ?? AuthRepository(),
        _onSignedOut = onSignedOut,
        _retryDio = retryClient ?? Dio();

  static const _refreshWindow = Duration(seconds: 30);

  final TokenStore _store;
  final AuthRepository _auth;
  final FutureOr<void> Function()? _onSignedOut;

  /// Coalesces concurrent refreshes so a burst of expiring requests shares one
  /// round trip.
  Future<_RefreshResult>? _pendingRefresh;

  /// Bare Dio for the post-401 replay. It carries no interceptors, which is
  /// what keeps a replay from re-entering this one.
  final Dio _retryDio;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Dio drops the future this returns and waits on the handler instead, so
    // an error escaping here would leave the caller waiting forever.
    AuthSession? session;
    Object? failure;
    try {
      session = await _currentSession();
    } catch (e) {
      failure = e;
    }

    if (session == null) {
      handler.reject(
        DioException(
          requestOptions: options,
          error: failure ?? const AuthException('no signed-in session'),
        ),
      );
      return;
    }

    options.headers['Authorization'] = 'Bearer ${session.accessToken}';
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    Response<dynamic>? replayed;
    try {
      replayed = await _replayAfterRefresh(err);
    } catch (e) {
      developer.log(
        'Recovering from 401 failed: $e',
        name: 'AuthInterceptor',
        level: 1000,
      );
    }

    if (replayed == null) {
      handler.next(err);
    } else {
      handler.resolve(replayed);
    }
  }

  /// Refreshes and replays a request the server answered with 401, or returns
  /// null to let it keep its original error.
  Future<Response<dynamic>?> _replayAfterRefresh(DioException err) async {
    if (err.response?.statusCode != 401) return null;

    final options = err.requestOptions;
    // A FormData body is finalised on the way out and cannot be sent twice, so
    // replaying a photo upload would report that instead of the 401.
    if (options.data is FormData) return null;

    final refreshToken = (await _store.read())?.refreshToken;
    if (refreshToken == null) {
      // The token was refused and there is nothing to refresh from.
      await _endSession();
      return null;
    }

    final result = await _refresh(refreshToken);
    final session = result.session;
    if (session == null) {
      if (result.sessionDead) await _endSession();
      return null;
    }

    options.headers['Authorization'] = 'Bearer ${session.accessToken}';
    return _retryDio.fetch(options);
  }

  Future<AuthSession?> _currentSession() async {
    final stored = await _store.read();
    if (stored == null) return null;
    if (!stored.expiresWithin(_refreshWindow)) return stored;

    // An expiring session with nothing to refresh from still gets its shot:
    // the 401 path ends it if the server disagrees.
    final refreshToken = stored.refreshToken;
    if (refreshToken == null) return stored;

    final result = await _refresh(refreshToken);
    if (result.session != null) return result.session;
    if (result.sessionDead) {
      await _endSession();
      return null;
    }
    // The refresh never reached the server. Send the token we have and let the
    // response decide, rather than signing someone out over a dropped packet.
    return stored;
  }

  Future<_RefreshResult> _refresh(String refreshToken) {
    final pending = _pendingRefresh;
    if (pending != null) return pending;

    final started = _attemptRefresh(refreshToken);
    _pendingRefresh = started;
    unawaited(
      started.whenComplete(() {
        if (identical(_pendingRefresh, started)) _pendingRefresh = null;
      }),
    );
    return started;
  }

  Future<_RefreshResult> _attemptRefresh(String refreshToken) async {
    try {
      return (session: await _auth.refresh(refreshToken), sessionDead: false);
    } on AuthGrantRejectedException catch (e) {
      developer.log(
        'Refresh grant rejected: $e',
        name: 'AuthInterceptor',
        level: 1000,
      );
      return (session: null, sessionDead: true);
    } catch (e) {
      developer.log(
        'Token refresh could not be delivered: $e',
        name: 'AuthInterceptor',
        level: 900,
      );
      return (session: null, sessionDead: false);
    }
  }

  Future<void> _endSession() async {
    await _auth.signOut();
    await _onSignedOut?.call();
  }
}
