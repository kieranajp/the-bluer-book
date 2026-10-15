/// A public PKCE client: no secret ships in the binary, and AppAuth reads every
/// endpoint from [discoveryUrl].
class OAuthConfig {
  static const String discoveryUrl = String.fromEnvironment(
    'OAUTH_DISCOVERY_URL',
    defaultValue:
        'https://auth.kieranajp.uk/application/o/the-bluer-book/.well-known/openid-configuration',
  );

  /// Must match Authentik's `allowed_redirect_uris` byte for byte, and the
  /// scheme must stay registered in the Android manifest and iOS URL types.
  static const String redirectUri = String.fromEnvironment(
    'OAUTH_REDIRECT_URI',
    defaultValue: 'com.thebluerbook.app://oauth/callback',
  );

  static const String clientId = String.fromEnvironment(
    'OAUTH_CLIENT_ID',
    defaultValue: '',
  );

  static const String _scopes = String.fromEnvironment(
    'OAUTH_SCOPES',
    defaultValue: 'openid email profile offline_access recipes:api',
  );

  /// `offline_access` is what earns a refresh token. Drop it and every session
  /// dies when the access token expires.
  static List<String> get scopes =>
      _scopes.split(' ').where((scope) => scope.isNotEmpty).toList();
}
