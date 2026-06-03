import 'dart:developer' as dev;

import 'package:posthog_flutter/posthog_flutter.dart';

import '../config/analytics_config.dart';
import 'analytics.dart';

/// [Analytics] backed by PostHog. Wraps the PostHog Flutter SDK singleton; the
/// SDK must be initialised once via [PostHogAnalytics.setup] before any events
/// are sent (call it from `main()`).
class PostHogAnalytics implements Analytics {
  const PostHogAnalytics();

  /// Initialise the PostHog SDK. A no-op when analytics isn't configured.
  /// Call once, before `runApp`, after `WidgetsFlutterBinding.ensureInitialized()`.
  static Future<void> setup() async {
    if (!AnalyticsConfig.isEnabled) return;
    final config = PostHogConfig(AnalyticsConfig.apiKey)
      ..host = AnalyticsConfig.host
      // "Application Opened/Backgrounded" lifecycle events, for free.
      ..captureApplicationLifecycleEvents = true;
    await Posthog().setup(config);
    dev.log('PostHog initialised (host=${AnalyticsConfig.host})',
        name: 'PostHogAnalytics');
  }

  @override
  Future<void> screen(String name, {Map<String, Object>? properties}) {
    return Posthog().screen(screenName: name, properties: properties);
  }

  @override
  Future<void> capture(String event, {Map<String, Object>? properties}) {
    return Posthog().capture(eventName: event, properties: properties);
  }

  @override
  Future<void> identify(String distinctId, {Map<String, Object>? properties}) {
    return Posthog().identify(userId: distinctId, userProperties: properties);
  }

  @override
  Future<void> reset() => Posthog().reset();
}
