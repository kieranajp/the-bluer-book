/// Product analytics — a thin abstraction over wherever usage events are sent
/// (currently PostHog; see `posthog_analytics.dart`). The rest of the app talks
/// to this interface only. [NoopAnalytics] is the safe default when analytics
/// isn't configured (no API key) and in tests, so call sites can fire events
/// unconditionally without null-checks.
///
/// Mirrors the backend's `recipe.Probe` shape: an interface the app fires
/// against, a no-op for when there's nothing listening, and the real
/// implementation living in infrastructure.
abstract interface class Analytics {
  /// Record a screen view. [name] is a human-readable screen label — use the
  /// [AnalyticsScreen] constants.
  Future<void> screen(String name, {Map<String, Object>? properties});

  /// Record a custom event. [event] is one of the [AnalyticsEvent] constants.
  Future<void> capture(String event, {Map<String, Object>? properties});

  /// Associate subsequent events with a known user.
  Future<void> identify(String distinctId, {Map<String, Object>? properties});

  /// Forget the current user (e.g. on sign-out).
  Future<void> reset();
}

/// Custom event names. Centralised so the vocabulary stays consistent and
/// greppable — never inline a raw event string at a call site.
class AnalyticsEvent {
  const AnalyticsEvent._();

  static const recipeOpened = 'recipe_opened';
  static const recipeSearched = 'recipe_searched';
  static const recipeCreated = 'recipe_created';
  static const recipeUpdated = 'recipe_updated';
  static const recipeArchived = 'recipe_archived';
  static const mealPlanToggled = 'meal_plan_toggled';
  static const cookingModeStarted = 'cooking_mode_started';
  static const chatMessageSent = 'chat_message_sent';
}

/// Human-readable screen names, surfaced in PostHog's screen reports.
class AnalyticsScreen {
  const AnalyticsScreen._();

  static const home = 'Home';
  static const mealPlan = 'Meal Plan';
  static const pantry = 'Pantry';
  static const recipe = 'Recipe';
  static const chat = 'Chat';
}

/// Analytics that does nothing, successfully. The default when no API key is
/// configured, and what tests get.
class NoopAnalytics implements Analytics {
  const NoopAnalytics();

  @override
  Future<void> screen(String name, {Map<String, Object>? properties}) async {}

  @override
  Future<void> capture(String event, {Map<String, Object>? properties}) async {}

  @override
  Future<void> identify(String distinctId,
      {Map<String, Object>? properties}) async {}

  @override
  Future<void> reset() async {}
}
