/// OAuth2 configuration for the-bluer-book's Authentik client.
///
/// A person signs in with the authorization-code grant and PKCE, so this is a
/// public client and no secret ships in the binary. AppAuth reads every
/// endpoint from [discoveryUrl] and runs the code exchange natively.
class OAuthConfig {
  static const String discoveryUrl = String.fromEnvironment(
    'OAUTH_DISCOVERY_URL',
    defaultValue:
        'https://auth.kieranajp.uk/application/o/the-bluer-book/.well-known/openid-configuration',
  );

  /// Must match the provider's `allowed_redirect_uris` byte for byte —
  /// Authentik matches it literally, and the scheme is registered with the
  /// platform in the Android manifest placeholder and the iOS URL types.
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
