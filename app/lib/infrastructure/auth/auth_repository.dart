import 'package:flutter_appauth/flutter_appauth.dart';

import '../config/oauth_config.dart';
import 'token_store.dart';

/// Authentik declined to issue tokens, or returned a response the app cannot
/// use.
class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => 'AuthException: $message';
}

/// The person closed the browser without finishing sign-in.
class AuthCancelledException extends AuthException {
  const AuthCancelledException() : super('sign-in was cancelled');
}

/// The server rejected the refresh grant, so the session is finished and only
/// a fresh sign-in gets it back. Distinct from a refresh that merely could not
/// be delivered, which leaves the grant intact.
class AuthGrantRejectedException extends AuthException {
  const AuthGrantRejectedException() : super('the refresh grant was rejected');
}

/// Runs the authorization-code + PKCE flow against Authentik and keeps the
/// resulting session in [TokenStore].
///
/// AppAuth opens the browser, generates the PKCE verifier and exchanges the
/// code natively, so nothing in the app's HTTP stack ever sees the token
/// endpoint.
class AuthRepository {
  AuthRepository({TokenStore? store, FlutterAppAuth? appAuth})
      : _store = store ?? TokenStore(),
        _appAuth = appAuth ?? const FlutterAppAuth();

  final TokenStore _store;
  final FlutterAppAuth _appAuth;

  Future<AuthSession> signIn() async {
    try {
      final response = await _appAuth.authorizeAndExchangeCode(
        AuthorizationTokenRequest(
          OAuthConfig.clientId,
          OAuthConfig.redirectUri,
          discoveryUrl: OAuthConfig.discoveryUrl,
          scopes: OAuthConfig.scopes,
        ),
      );
      return await _persist(response, null);
    } on FlutterAppAuthUserCancelledException {
      throw const AuthCancelledException();
    }
  }

  Future<AuthSession> refresh(String refreshToken) async {
    try {
      final response = await _appAuth.token(
        TokenRequest(
          OAuthConfig.clientId,
          OAuthConfig.redirectUri,
          discoveryUrl: OAuthConfig.discoveryUrl,
          refreshToken: refreshToken,
          scopes: OAuthConfig.scopes,
        ),
      );
      return await _persist(response, refreshToken);
    } on FlutterAppAuthPlatformException catch (e) {
      if (_rejectedGrantErrors.contains(e.platformErrorDetails.error)) {
        throw const AuthGrantRejectedException();
      }
      rethrow;
    }
  }

  /// The OAuth error codes that mean the grant itself is finished. Every other
  /// failure — no network, a restarting server, a plugin fault — says nothing
  /// about the grant.
  static const _rejectedGrantErrors = {
    FlutterAppAuthOAuthError.invalidGrant,
    FlutterAppAuthOAuthError.invalidClient,
    FlutterAppAuthOAuthError.unauthorizedClient,
  };

  Future<void> signOut() => _store.clear();

  /// A refresh response omits `refresh_token` when the server reuses the
  /// existing grant, so [previousRefreshToken] carries it forward.
  Future<AuthSession> _persist(
    TokenResponse response,
    String? previousRefreshToken,
  ) async {
    final accessToken = response.accessToken;
    if (accessToken == null || accessToken.isEmpty) {
      throw const AuthException('the token response carried no access token');
    }

    final session = AuthSession(
      accessToken: accessToken,
      refreshToken: response.refreshToken ?? previousRefreshToken,
      expiresAt: response.accessTokenExpirationDateTime,
    );
    await _store.write(session);
    return session;
  }
}
