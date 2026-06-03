/// Build-time configuration for product analytics (PostHog), supplied via
/// `--dart-define`. With no API key the app falls back to `NoopAnalytics`, so
/// local and dev builds send nothing unless you opt in:
///
/// ```sh
/// flutter run \
///   --dart-define=API_URL=http://localhost:8080 \
///   --dart-define=POSTHOG_API_KEY=phc_xxx \
///   --dart-define=POSTHOG_HOST=https://eu.i.posthog.com
/// ```
class AnalyticsConfig {
  const AnalyticsConfig._();

  /// PostHog project API key. Empty ⇒ analytics disabled.
  static const String apiKey = String.fromEnvironment('POSTHOG_API_KEY');

  /// PostHog ingestion host. Defaults to EU cloud (where our project lives);
  /// override for US (`https://us.i.posthog.com`) or a self-hosted instance.
  static const String host = String.fromEnvironment(
    'POSTHOG_HOST',
    defaultValue: 'https://eu.i.posthog.com',
  );

  /// Analytics is only active when an API key was provided at build time.
  static bool get isEnabled => apiKey.isNotEmpty;
}
