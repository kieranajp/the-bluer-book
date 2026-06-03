import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../infrastructure/analytics/analytics.dart';
import '../../infrastructure/analytics/posthog_analytics.dart';
import '../../infrastructure/config/analytics_config.dart';

/// The app-wide [Analytics] sink. Resolves to [PostHogAnalytics] when an API
/// key was configured at build time, otherwise [NoopAnalytics] so call sites
/// fire events unconditionally. PostHog must already be initialised via
/// [PostHogAnalytics.setup] in `main()`.
final analyticsProvider = Provider<Analytics>((ref) {
  return AnalyticsConfig.isEnabled
      ? const PostHogAnalytics()
      : const NoopAnalytics();
});
