class OAuthConfig {
  static const String tokenUrl = String.fromEnvironment(
    'OAUTH_TOKEN_URL',
    defaultValue: 'https://hydra.kieranajp.uk/oauth2/token',
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
    defaultValue: 'bluer-book:api',
  );
}
