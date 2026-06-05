/// Kratos public-facing config. Overrideable from `--dart-define` so the
/// release.env in CI can point at the homelab while dev defaults to the
/// production host (same as the API). The deep-link scheme matches the
/// CFBundleURLScheme on iOS and the CallbackActivity intent filter on
/// Android — keep all three in lock-step if it ever changes.
class KratosConfig {
  static const String publicUrl = String.fromEnvironment(
    'KRATOS_URL',
    defaultValue: 'https://kratos.kieranajp.uk',
  );

  /// Stable Kratos-internal id of the Google OIDC provider, matching the
  /// `id:` field in the Kratos `selfservice.methods.oidc.config.providers`
  /// list. Used to construct the social-login deep link.
  static const String googleProviderId = 'google';

  /// Custom scheme the Kratos browser flow's `return_to` URL points at.
  /// `flutter_web_auth_2` listens for this scheme and resolves the
  /// authenticate() future with the full incoming URI.
  static const String callbackScheme = 'com.thebluerbook.app';
  static const String callbackHost = 'oauth';
  static const String callbackPath = '/callback';

  /// Full URL that Kratos uses as `return_to` once the social sign-in
  /// completes — Kratos appends the session_token_exchange `code` as a
  /// query parameter when the flow was initialised with token exchange.
  static String get returnTo => '$callbackScheme://$callbackHost$callbackPath';
}
