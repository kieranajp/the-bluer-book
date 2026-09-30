import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AppTab { recipes, mealPlan, pantry }

/// The selected bottom-nav tab, held outside AppShell so any widget can switch
/// tabs.
class SelectedTabNotifier extends Notifier<AppTab> {
  @override
  AppTab build() => AppTab.recipes;

  void select(AppTab tab) => state = tab;
}

final selectedTabProvider = NotifierProvider<SelectedTabNotifier, AppTab>(
  SelectedTabNotifier.new,
);
