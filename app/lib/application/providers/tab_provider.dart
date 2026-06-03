import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../infrastructure/analytics/analytics.dart';
import 'analytics_providers.dart';

/// Currently selected bottom-nav tab index. Lifted out of AppShell so any
/// widget in the tree can hop to a different tab (e.g. "view meal plan"
/// from the home carousel).
class SelectedTabNotifier extends Notifier<int> {
  /// Screen name per tab index, for analytics. Order matches AppShell's tabs.
  static const _screens = [
    AnalyticsScreen.home,
    AnalyticsScreen.mealPlan,
    AnalyticsScreen.pantry,
  ];

  @override
  int build() => 0;

  void select(int index) {
    if (index == state) return;
    state = index;
    if (index >= 0 && index < _screens.length) {
      ref.read(analyticsProvider).screen(_screens[index]);
    }
  }
}

final selectedTabProvider =
    NotifierProvider<SelectedTabNotifier, int>(SelectedTabNotifier.new);
