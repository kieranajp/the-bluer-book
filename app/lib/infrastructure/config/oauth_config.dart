/// OAuth2 endpoints and client credentials for the-bluer-book.
///
/// Tokens are issued by Authentik (the OAuth2 provider/application
/// `the-bluer-book`), which replaced the previous Ory Hydra client.
///
/// The app authenticates today with the `client_credentials` grant, which only
/// needs [tokenUrl] + [clientId]/[clientSecret]. The authorization, JWKS and
/// discovery URLs plus [redirectUri] are the Authentik endpoints for the
/// upcoming user-facing auth-code + PKCE login flow; they are defined here so
/// the whole OAuth config points at Authentik in one place.
class OAuthConfig {
  static const String tokenUrl = String.fromEnvironment(
    'OAUTH_TOKEN_URL',
    defaultValue: 'https://auth.kieranajp.uk/application/o/token/',
  );

  static const String authorizationUrl = String.fromEnvironment(
    'OAUTH_AUTHORIZATION_URL',
    defaultValue: 'https://auth.kieranajp.uk/application/o/authorize/',
  );

  static const String jwksUrl = String.fromEnvironment(
    'OAUTH_JWKS_URL',
    defaultValue:
        'https://auth.kieranajp.uk/application/o/the-bluer-book/jwks/',
  );

  static const String discoveryUrl = String.fromEnvironment(
    'OAUTH_DISCOVERY_URL',
    defaultValue:
        'https://auth.kieranajp.uk/application/o/the-bluer-book/.well-known/openid-configuration',
  );

  static const String redirectUri = String.fromEnvironment(
    'OAUTH_REDIRECT_URI',
    defaultValue: 'com.thebluerbook.app://oauth/callback',
  );

  static const String clientId = String.fromEnvironment(
    'OAUTH_CLIENT_ID',
    defaultValue: '',
  );

  static const String clientSecret = String.fromEnvironment(
    'OAUTH_CLIENT_SECRET',
    defaultValue: '',
  );

  static const String scope = String.fromEnvironment(
    'OAUTH_SCOPE',
    defaultValue: 'recipes:api',
  );
}
